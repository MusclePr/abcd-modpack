package com.abcd.modpack;

import java.io.*;
import java.net.URI;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.Instant;
import java.util.*;
import java.util.regex.*;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public class Updater {
    public static void main(String[] args) throws Exception {
        // コンソール出力のための親ウィンドウを作成
        javax.swing.JFrame frame = new javax.swing.JFrame("A-B-C-D Modpack Updater");
        frame.setDefaultCloseOperation(javax.swing.JFrame.EXIT_ON_CLOSE);
        frame.setSize(800, 400);
        frame.setLocationRelativeTo(null); // 画面中央に配置
        frame.setAlwaysOnTop(true); // 常に最前面に表示
        frame.setVisible(false); // 初期表示は非表示
        // コンソール出力を表示するためのテキストエリア（日本語対応）
        javax.swing.JTextArea textArea = new javax.swing.JTextArea();
        textArea.setEditable(false);
        textArea.setFont(new java.awt.Font("Monospaced", java.awt.Font.PLAIN, 14));
        textArea.setLineWrap(true);
        textArea.setWrapStyleWord(true);
        textArea.setCaretPosition(0); // 初期カーソル位置を先頭
        javax.swing.JScrollPane scrollPane = new javax.swing.JScrollPane(textArea);
        frame.getContentPane().add(scrollPane, java.awt.BorderLayout.CENTER);
        // コンソール出力をテキストエリアにリダイレクト
        PrintStream console = new PrintStream(new OutputStream() {
            @Override
            // UTF-8での文字化けを防ぐため、OutputStreamWriterを使用
            public void write(byte[] b, int off, int len) {
                String str = new String(b, off, len, StandardCharsets.UTF_8);
                textArea.append(str);
                textArea.setCaretPosition(textArea.getDocument().getLength()); // 常に最新の出力を表示
            }
            public void write(int b) {
                textArea.append(String.valueOf((char) b));
                textArea.setCaretPosition(textArea.getDocument().getLength()); // 常に最新の出力を表示
            }
        });
        System.setOut(console);
        System.setErr(console);
        frame.setVisible(true);

        // --uninstall-caオプションが指定された場合、CA証明書のアンインストールを実行
        if (args.length > 0 && args[0].equals("--uninstall-ca")) {
            uninstallCACertificate(frame);
            // コンソールウィンドウを閉じる
            frame.dispose();
            return;
        }

        // 1. バージョンアップが必要かどうかの確認
        String version = "0.0-SNAPSHOT"; // デフォルト値
        try {
            InputStream inputStream = Updater.class.getResourceAsStream("/META-INF/maven/com.abcd/abcd-modpack/pom.properties");
            if (inputStream != null) {
                System.out.println("pom.properties の読み込みに成功しました。");
                Properties props = new Properties();
                props.load(inputStream);
                version = props.getProperty("version", version);
                inputStream.close();
            }
        } catch (IOException e) {
            System.err.println("pom.properties の読み込みに失敗しました: " + e.getMessage());
        }
        System.out.println("A-B-C-D Modpack Updater v" + version);

        // 最新バージョン取得
        // １行目：マイクラバージョン
        // ２行目：アップデーターバージョン
        String text = fetchText("https://a-b-c-d.com/downloads/abcd-mods-latest.txt");
        String[] lines = text.split(text.contains("\r\n") ? "\r\n" : "\n");
        if (lines.length < 2) {
            System.out.println("最新バージョン情報の取得に失敗しました。");
            return;
        }
        String ver = lines[0].trim();
        String latestVersion = lines[1].trim();
        System.out.println("Minecraft Version: " + ver);
        System.out.println("Latest Version: " + latestVersion);
        if (!version.equals(latestVersion)) {
            String message = "A-B-C-D Modpack Updater のバージョンが古いです。\n" +
                "現在のバージョン: " + version + "\n" +
                "最新バージョン: " + latestVersion + "\n" +
                "アップデートを行ってください。\n" +
                "https://a-b-c-d.com/modpacks/";
            System.out.println(message);
            javax.swing.JOptionPane.showMessageDialog(frame, message, "通知", javax.swing.JOptionPane.INFORMATION_MESSAGE);
            // 既定のブラウザを起動する
            java.awt.Desktop.getDesktop().browse(URI.create("https://a-b-c-d.com/modpacks/#arkb-toc-1"));
            // コンソールウィンドウを閉じる
            frame.dispose();
            return;
        }

        // 2. 作業ディレクトリの作成
        Path gameDir = Paths.get(System.getenv("APPDATA"), ".minecraft_abcd");
        Files.createDirectories(gameDir);
        System.out.println("作業ディレクトリ: " + gameDir);

        // 3. Minecraftプロセスの検出
        while (isMinecraftRunning()) {
            System.out.println("Minecraft のランチャーを終了してください。");
            javax.swing.JOptionPane.showMessageDialog(frame, "Minecraft のランチャーを終了してください。", "警告", javax.swing.JOptionPane.WARNING_MESSAGE);
            Thread.sleep(1000);
        }
        System.out.println("Minecraft のランチャーが起動していない事を確認しました。");

        // 4. Java実行ファイルのパス検出
        Path javaExe = detectJava();
        if (javaExe == null) {
            System.out.println("Java 実行ファイルが見つかりません。");
            return;
        }

        // 5. fabricインストーラのバージョン取得・ダウンロード
        String fabricVersion = fetchLatestFabricVersion();
        Path fabricJar = downloadFabricInstaller(gameDir, fabricVersion);

        // 6. fabricインストーラ実行
        String loaderVersion = runFabricInstaller(javaExe, fabricJar, ver);

        // 7. launcher_profiles.jsonの編集
        updateLauncherProfiles(ver, loaderVersion, gameDir);

        // 8. ModPackリストのダウンロード・処理
        processModpackList(gameDir, ver);

        // 9. CA証明書のチェックとインストール
        checkAndInstallCACertificate(frame);

        System.out.println("正常に完了しました。マインクラフトのランチャーを起動して、起動構成「A-B-C-D " + ver + "」から起動してください。");
        javax.swing.JOptionPane.showMessageDialog(frame, "正常に完了しました。マインクラフトのランチャーを起動して、起動構成「A-B-C-D " + ver + "」から起動してください。", "通知", javax.swing.JOptionPane.INFORMATION_MESSAGE);
        
        // コンソールウィンドウを閉じる
        frame.dispose();
    }

    static boolean isMinecraftRunning() {
        return ProcessHandle.allProcesses()
            .anyMatch(ph -> ph.info().command().map(cmd -> cmd.toLowerCase().contains("minecraft")).orElse(false));
    }

    static String fetchText(String url) throws Exception {
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest req = HttpRequest.newBuilder().uri(URI.create(url)).build();
        HttpResponse<String> resp = client.send(req, HttpResponse.BodyHandlers.ofString());
        return resp.body();
    }

    static Path detectJava() {
        String localAppData = System.getenv("LOCALAPPDATA");
        Path msJava = Paths.get(localAppData, "Packages", "Microsoft.4297127D64EC6_8wekyb3d8bbwe", "LocalCache", "Local", "runtime", "java-runtime-delta", "windows-x64", "java-runtime-delta", "bin", "java.exe");
        if (Files.exists(msJava)) return msJava;
        String javaHome = System.getenv("JAVA_HOME");
        if (javaHome != null) {
            Path javaHomeExe = Paths.get(javaHome, "bin", "java.exe");
            if (Files.exists(javaHomeExe)) return javaHomeExe;
        }
        return null;
    }

    static String fetchLatestFabricVersion() throws Exception {
        String html = fetchText("https://maven.fabricmc.net/net/fabricmc/fabric-installer/");
        Pattern p = Pattern.compile("href=\"([0-9]+\\.[0-9]+\\.[0-9]+)/\"");
        Matcher m = p.matcher(html);
        List<String> versions = new ArrayList<>();
        while (m.find()) {
            versions.add(m.group(1));
        }
        versions.sort(Comparator.comparing(v -> Arrays.stream(v.split("\\.")).mapToInt(Integer::parseInt).toArray(), Arrays::compare));
        return versions.get(versions.size() - 1);
    }

    static Path downloadFabricInstaller(Path dir, String version) throws Exception {
        String url = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/" + version + "/fabric-installer-" + version + ".jar";
        Path dest = dir.resolve("fabric-installer-" + version + ".jar");
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest req = HttpRequest.newBuilder().uri(URI.create(url)).build();
        HttpResponse<Path> resp = client.send(req, HttpResponse.BodyHandlers.ofFile(dest));
        return resp.body();
    }

    static String runFabricInstaller(Path javaExe, Path fabricJar, String mcVersion) throws Exception {
        // Fabricインストーラを実行してローダーバージョンを取得
        System.out.println("Java 実行ファイル: " + javaExe);
        System.out.println("Fabric インストーラのパス: " + fabricJar);
        Process proc = new ProcessBuilder(javaExe.toString(), "-jar", fabricJar.toString(), "client", "-mcversion", mcVersion)
            .redirectErrorStream(true).start();
        
        // Windowsでの文字化け対策：複数のエンコーディングを試行
        BufferedReader reader = null;
        try {
            // まずShift_JISを試す（Windowsの日本語環境で一般的）
            reader = new BufferedReader(new InputStreamReader(proc.getInputStream(), "Shift_JIS"));
        } catch (Exception e) {
            // Shift_JISが利用できない場合はシステムデフォルトを使用
            String encoding = System.getProperty("file.encoding", "UTF-8");
            reader = new BufferedReader(new InputStreamReader(proc.getInputStream(), encoding));
        }
        
        String line, loaderVersion = null;
        while ((line = reader.readLine()) != null) {
            if (line.matches(".*with fabric (\\d+\\.\\d+\\.\\d+).*") && loaderVersion == null) {
                loaderVersion = line.replaceAll(".*with fabric (\\d+\\.\\d+\\.\\d+).*", "$1");
            }
            System.out.println(line);
        }
        proc.waitFor();
        if (loaderVersion == null) throw new RuntimeException("ローダーバージョンの取得に失敗しました。");
        return loaderVersion;
    }

    static void updateLauncherProfiles(String ver, String loaderVersion, Path gameDir) throws Exception {
        Path profilePath = Paths.get(System.getenv("APPDATA"), ".minecraft", "launcher_profiles.json");
        String jsonText = Files.readString(profilePath, StandardCharsets.UTF_8);
        
        // JSON処理を文字列操作で実装（Jacksonライブラリ不要）
        // 既存のプロファイルを削除する正規表現処理
        String profileKey = "\"fabric-loader-" + ver + "\"";
        jsonText = removeJsonProfile(jsonText, profileKey);
        
        // 新しいプロファイルを追加
        String profileId = "\"A-B-C-D\"";
        String created = Instant.now().toString();
        String newProfile = String.format(
            "    %s: {\n" +
            "      \"created\": \"%s\",\n" +
            "      \"gameDir\": \"%s\",\n" +
            "      \"icon\": \"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACABAMAAAAxEHz4AAAAGFBMVEUAAAA4NCrb0LTGvKW8spyAem2uppSakn5SsnMLAAAAAXRSTlMAQObYZgAAAJ5JREFUaIHt1MENgCAMRmFWYAVXcAVXcAVXcH3bhCYNkYjcKO8dSf7v1JASUWdZAlgb0PEmDSMAYYBdGkYApgf8ER3SbwRgesAf0BACMD1gB6S9IbkEEBfwY49oNj4lgLhA64C0o9R9RABTAvp4SX5kB2TA5y8EEAK4pRrxB9QcA4QBWkj3GCAMUCO/xwBhAI/kEsCagCHDY4AwAC3VA6t4zTAMj0OJAAAAAElFTkSuQmCC\",\n" +
            "      \"javaArgs\": \"-Xmx4G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M\",\n" +
            "      \"lastUsed\": \"1970-01-01T00:00:00.000Z\",\n" +
            "      \"lastVersionId\": \"fabric-loader-%s-%s\",\n" +
            "      \"name\": \"A-B-C-D %s\",\n" +
            "      \"type\": \"custom\"\n" +
            "    }",
            profileId, created, gameDir.toString().replace("\\", "\\\\"), loaderVersion, ver, ver
        );
        
        // profiles セクションに新しいプロファイルを追加
        jsonText = addJsonProfile(jsonText, newProfile);
        
        Files.writeString(profilePath, jsonText, StandardCharsets.UTF_8);
    }
    
    static String removeJsonProfile(String jsonText, String profileKey) {
        // 指定されたプロファイルキーを含む行とその値を削除
        String regex = "\\s*" + Pattern.quote(profileKey) + ":\\s*\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\},?\\s*";
        return jsonText.replaceAll(regex, "");
    }
    
    static String addJsonProfile(String jsonText, String newProfile) {
        // "profiles" セクションを見つけて新しいプロファイルを追加
        String profilesPattern = "(\"profiles\"\\s*:\\s*\\{)";
        Matcher matcher = Pattern.compile(profilesPattern).matcher(jsonText);
        if (matcher.find()) {
            int insertPos = matcher.end();
            // 既存のプロファイルがある場合はカンマを追加
            String beforeInsert = jsonText.substring(0, insertPos);
            String afterInsert = jsonText.substring(insertPos);
            
            // 既存のプロファイルの後にカンマが必要かチェック
            String toInsert = newProfile;
            if (afterInsert.trim().startsWith("\"")) {
                toInsert = newProfile + ",";
            }
            if (!beforeInsert.trim().endsWith("{")) {
                toInsert = "," + toInsert;
            }
            
            return beforeInsert + "\n" + toInsert + afterInsert;
        }
        return jsonText;
    }

    static void processModpackList(Path gameDir, String ver) throws Exception {
        String packs = "abcd-update-packs-" + ver + ".txt";
        Path packsPath = gameDir.resolve(packs);
        Files.deleteIfExists(packsPath);
        System.out.println("Download ... " + packs);
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest req = HttpRequest.newBuilder().uri(URI.create("https://a-b-c-d.com/downloads/" + packs)).build();
        client.send(req, HttpResponse.BodyHandlers.ofFile(packsPath));
        List<String> lines = Files.readAllLines(packsPath, StandardCharsets.UTF_8);
        for (String line : lines) {
            if (line.isEmpty() || line.charAt(0) == '#') continue;
            System.out.println("Processing: " + line);
            char op = line.charAt(0);
            String value = line.substring(1);
            
            if (op == '-') {
                System.out.println("Remove: " + value);
                removeFilesWithPattern(gameDir, value);
            } else if (op == '+') {
                String ext = value.substring(value.lastIndexOf('.'));
                System.out.println("Download: " + value);
                HttpRequest fileReq = HttpRequest.newBuilder().uri(URI.create("https://a-b-c-d.com/downloads/" + value)).build();
                Path outFile = gameDir.resolve(value);
                client.send(fileReq, HttpResponse.BodyHandlers.ofFile(outFile));
                if (".zip".equalsIgnoreCase(ext)) {
                    System.out.println("Unzip: " + outFile);
                    unzip(outFile, gameDir);
                    Files.deleteIfExists(outFile);
                }
            }
        }
    }

    static void removeFilesWithPattern(Path baseDir, String pattern) throws IOException {
        // パターンを手動で分離（Paths.get使用不可のため）
        String normalizedPattern = pattern.replace('\\', '/');
        int lastSlash = normalizedPattern.lastIndexOf('/');
        
        String parentPath = null;
        String fileName;
        
        if (lastSlash >= 0) {
            parentPath = normalizedPattern.substring(0, lastSlash);
            fileName = normalizedPattern.substring(lastSlash + 1);
        } else {
            fileName = normalizedPattern;
        }
        
        // 基準ディレクトリからの相対パスを解決
        Path searchDir = baseDir;
        if (parentPath != null) {
            // パス区切り文字を正規化してPathを作成
            String[] pathParts = parentPath.split("/");
            for (String part : pathParts) {
                searchDir = searchDir.resolve(part);
            }
        }
        
        // ディレクトリが存在しない場合は何もしない
        if (!Files.exists(searchDir) || !Files.isDirectory(searchDir)) {
            System.out.println("Directory not found: " + searchDir);
            return;
        }
        
        // ワイルドカードパターンを正規表現に変換
        String regex = convertWildcardToRegex(fileName);
        Pattern filePattern = Pattern.compile(regex);
        
        // ディレクトリ内のファイルを検索して削除
        try (var stream = Files.list(searchDir)) {
            stream.filter(Files::isRegularFile)
                  .filter(path -> filePattern.matcher(path.getFileName().toString()).matches())
                  .forEach(path -> {
                      try {
                          System.out.println("Deleting: " + path);
                          Files.delete(path);
                      } catch (IOException e) {
                          System.err.println("Failed to delete: " + path + " - " + e.getMessage());
                      }
                  });
        }
    }
    
    static String convertWildcardToRegex(String wildcardPattern) {
        // ワイルドカードパターンを正規表現に変換
        StringBuilder regex = new StringBuilder();
        for (int i = 0; i < wildcardPattern.length(); i++) {
            char c = wildcardPattern.charAt(i);
            switch (c) {
                case '*':
                    regex.append(".*");
                    break;
                case '?':
                    regex.append(".");
                    break;
                case '.':
                    regex.append("\\.");
                    break;
                case '^':
                case '$':
                case '+':
                case '{':
                case '}':
                case '[':
                case ']':
                case '(':
                case ')':
                case '|':
                case '\\':
                    regex.append("\\").append(c);
                    break;
                default:
                    regex.append(c);
                    break;
            }
        }
        return regex.toString();
    }

    static void unzip(Path zipFile, Path destDir) throws IOException {
        try (ZipInputStream zis = new ZipInputStream(Files.newInputStream(zipFile))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                Path outPath = destDir.resolve(entry.getName());
                if (entry.isDirectory()) {
                    Files.createDirectories(outPath);
                } else {
                    Files.createDirectories(outPath.getParent());
                    Files.copy(zis, outPath, StandardCopyOption.REPLACE_EXISTING);
                }
                zis.closeEntry();
            }
        }
    }

    static void checkAndInstallCACertificate(javax.swing.JFrame parentFrame) {
        try {
            System.out.println("CA証明書の確認を開始します...");
            
            // CA証明書のパスを取得
            Path certPath = getCACertificatePath();
            if (certPath == null || !Files.exists(certPath)) {
                System.out.println("CA証明書ファイルが見つかりません。");
                return;
            }
            
            System.out.println("CA証明書ファイルが見つかりました: " + certPath);
            
            // 証明書がインストール済みかチェック（簡略化）
            boolean isInstalled = false;
            try {
                isInstalled = isCACertificateInstalled();
            } catch (Exception e) {
                System.err.println("証明書確認でエラーが発生しました。インストールを試行します: " + e.getMessage());
                isInstalled = false;
            }
            
            if (isInstalled) {
                System.out.println("CA証明書は既にインストールされています。");
                return;
            }
            
            System.out.println("CA証明書がインストールされていません。");
            
            // ユーザーに確認
            int result = javax.swing.JOptionPane.showConfirmDialog(
                parentFrame,
                "ABCD Development CA証明書がインストールされていません。\n" +
                "セキュリティ警告を回避するためにインストールしますか？\n" +
                "（管理者権限が必要な場合があります）",
                "CA証明書のインストール",
                javax.swing.JOptionPane.YES_NO_OPTION,
                javax.swing.JOptionPane.QUESTION_MESSAGE
            );
            
            if (result == javax.swing.JOptionPane.YES_OPTION) {
                installCACertificate(certPath, parentFrame);
            } else {
                System.out.println("CA証明書のインストールをスキップしました。");
            }
            
        } catch (Exception e) {
            System.err.println("CA証明書の処理中にエラーが発生しました: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    static Path getCACertificatePath() {
        try {
            // JARファイル内のca-certificate.pemを一時ファイルにコピー
            InputStream certStream = Updater.class.getResourceAsStream("/ca-certificate.pem");
            if (certStream != null) {
                Path tempCert = Files.createTempFile("ca-certificate", ".pem");
                Files.copy(certStream, tempCert, StandardCopyOption.REPLACE_EXISTING);
                certStream.close();
                return tempCert;
            }
        } catch (IOException e) {
            System.err.println("JARファイル内からCA証明書を読み込めませんでした: " + e.getMessage());
        }
        
        // JARファイル内にない場合は、開発環境のパスを試す
        Path devCertPath = Paths.get("certificates", "ca-certificate.pem");
        if (Files.exists(devCertPath)) {
            return devCertPath;
        }
        
        // 実行ファイルと同じディレクトリを確認
        try {
            Path currentDir = Paths.get(System.getProperty("user.dir"));
            Path certPath = currentDir.resolve("ca-certificate.pem");
            if (Files.exists(certPath)) {
                return certPath;
            }
        } catch (Exception e) {
            System.err.println("証明書パスの解決に失敗しました: " + e.getMessage());
        }
        
        return null;
    }
    
    static boolean isCACertificateInstalled() {
        try {
            System.out.println("証明書ストアを確認中...");
            
            // より簡単なPowerShellコマンドで証明書ストアを確認
            ProcessBuilder pb = new ProcessBuilder(
                "powershell.exe", "-ExecutionPolicy", "Bypass", "-Command",
                "(Get-ChildItem Cert:\\LocalMachine\\Root | Where-Object {$_.Subject -match 'ABCD Development CA'}).Count"
            );
            pb.redirectErrorStream(true);
            Process process = pb.start();
            
            System.out.println("PowerShellプロセスを開始しました...");
            
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String output = "";
            String line;
            
            // 短いタイムアウトで読み取り
            boolean finished = process.waitFor(5, java.util.concurrent.TimeUnit.SECONDS);
            if (!finished) {
                System.err.println("PowerShellコマンドがタイムアウトしました。証明書チェックをスキップします。");
                process.destroyForcibly();
                return false; // タイムアウト時は未インストールとして扱う
            }
            
            while ((line = reader.readLine()) != null) {
                output += line.trim();
                System.out.println("PowerShell出力: " + line);
            }
            
            int exitCode = process.exitValue();
            System.out.println("PowerShell終了コード: " + exitCode);
            System.out.println("証明書確認結果: " + output);
            
            // 数値が0より大きければ証明書がインストール済み
            try {
                int count = Integer.parseInt(output.trim());
                return count > 0;
            } catch (NumberFormatException e) {
                System.err.println("PowerShell出力の解析に失敗しました: " + output);
                return false; // 解析失敗時は未インストールとして扱う
            }
            
        } catch (Exception e) {
            System.err.println("証明書インストール状況の確認に失敗しました: " + e.getMessage());
            return false; // エラー時は未インストールとして扱う
        }
    }

    static void uninstallCACertificate(javax.swing.JFrame parentFrame) {
        try {
            System.out.println("CA証明書をアンインストールしています...");
            
            // PowerShellコマンドで証明書をアンインストール
            ProcessBuilder pb = new ProcessBuilder(
                "powershell.exe", "-Command",
                "Get-ChildItem Cert:\\LocalMachine\\Root | Where-Object {$_.Subject -match 'ABCD Development CA'} | Remove-Item"
            );
            
            Process process = pb.start();
            
            // 出力を読み取り
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            BufferedReader errorReader = new BufferedReader(new InputStreamReader(process.getErrorStream()));
            
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println("PowerShell: " + line);
            }
            
            while ((line = errorReader.readLine()) != null) {
                System.err.println("PowerShell Error: " + line);
            }
            
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                System.out.println("CA証明書のアンインストールが完了しました。");
                javax.swing.JOptionPane.showMessageDialog(
                    parentFrame,
                    "CA証明書のアンインストールが完了しました。",
                    "証明書アンインストール完了",
                    javax.swing.JOptionPane.INFORMATION_MESSAGE
                );
            } else {
                System.err.println("CA証明書のアンインストールに失敗しました。終了コード: " + exitCode);
                javax.swing.JOptionPane.showMessageDialog(
                    parentFrame,
                    "CA証明書のアンインストールに失敗しました。\n管理者権限で実行してください。",
                    "証明書アンインストール失敗",
                    javax.swing.JOptionPane.ERROR_MESSAGE
                );
            }
            
        } catch (Exception e) {
            System.err.println("CA証明書のアンインストール中にエラーが発生しました: " + e.getMessage());
            javax.swing.JOptionPane.showMessageDialog(
                parentFrame,
                "CA証明書のアンインストール中にエラーが発生しました:\n" + e.getMessage(),
                "エラー",
                javax.swing.JOptionPane.ERROR_MESSAGE
            );
        }
    }

    static void installCACertificate(Path certPath, javax.swing.JFrame parentFrame) {
        try {
            System.out.println("CA証明書をインストールしています...");
            
            // PowerShellコマンドで証明書をインストール
            ProcessBuilder pb = new ProcessBuilder(
                "powershell.exe", "-Command",
                "Import-Certificate -FilePath '" + certPath.toString() + "' -CertStoreLocation Cert:\\LocalMachine\\Root"
            );
            
            Process process = pb.start();
            
            // 出力を読み取り
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            BufferedReader errorReader = new BufferedReader(new InputStreamReader(process.getErrorStream()));
            
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println("PowerShell: " + line);
            }
            
            while ((line = errorReader.readLine()) != null) {
                System.err.println("PowerShell Error: " + line);
            }
            
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                System.out.println("CA証明書のインストールが完了しました。");
                javax.swing.JOptionPane.showMessageDialog(
                    parentFrame,
                    "CA証明書のインストールが完了しました。",
                    "証明書インストール完了",
                    javax.swing.JOptionPane.INFORMATION_MESSAGE
                );
            } else {
                System.err.println("CA証明書のインストールに失敗しました。終了コード: " + exitCode);
                javax.swing.JOptionPane.showMessageDialog(
                    parentFrame,
                    "CA証明書のインストールに失敗しました。\n管理者権限で実行してください。",
                    "証明書インストール失敗",
                    javax.swing.JOptionPane.ERROR_MESSAGE
                );
            }
            
        } catch (Exception e) {
            System.err.println("CA証明書のインストール中にエラーが発生しました: " + e.getMessage());
            javax.swing.JOptionPane.showMessageDialog(
                parentFrame,
                "CA証明書のインストール中にエラーが発生しました:\n" + e.getMessage(),
                "エラー",
                javax.swing.JOptionPane.ERROR_MESSAGE
            );
        }
    }
}
