package com.abcd.modpack.fabric;

import com.abcd.modpack.network.NetworkUtils;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Path;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Fabric Loader のインストールを管理するクラス
 * Fabric インストーラーのダウンロードと実行を提供します
 */
public class FabricInstaller {
    private static final String FABRIC_MAVEN_URL = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/";
    private static final String FABRIC_INSTALLER_URL_TEMPLATE = 
        "https://maven.fabricmc.net/net/fabricmc/fabric-installer/%s/fabric-installer-%s.jar";
    
    /**
     * 最新の Fabric インストーラーバージョンを取得します
     * @return 最新バージョン文字列
     * @throws Exception ネットワークエラーまたはバージョン解析エラー
     */
    public static String fetchLatestFabricVersion() throws Exception {
        System.out.println("最新の Fabric インストーラーバージョンを取得中...");
        
        String html = NetworkUtils.fetchText(FABRIC_MAVEN_URL);
        Pattern pattern = Pattern.compile("href=\"([0-9]+\\.[0-9]+\\.[0-9]+)/\"");
        Matcher matcher = pattern.matcher(html);
        
        List<String> versions = new ArrayList<>();
        while (matcher.find()) {
            versions.add(matcher.group(1));
        }
        
        if (versions.isEmpty()) {
            throw new RuntimeException("Fabric インストーラーのバージョン情報が見つかりませんでした。");
        }
        
        // バージョンを数値比較でソート
        versions.sort(Comparator.comparing(v -> 
            Arrays.stream(v.split("\\."))
                .mapToInt(Integer::parseInt)
                .toArray(), 
            Arrays::compare));
        
        String latestVersion = versions.get(versions.size() - 1);
        System.out.println("最新の Fabric インストーラーバージョン: " + latestVersion);
        
        return latestVersion;
    }
    
    /**
     * Fabric インストーラーをダウンロードします
     * @param targetDir ダウンロード先ディレクトリ
     * @param version ダウンロードするバージョン
     * @return ダウンロードされたファイルのパス
     * @throws Exception ダウンロードエラー
     */
    public static Path downloadFabricInstaller(Path targetDir, String version) throws Exception {
        String url = String.format(FABRIC_INSTALLER_URL_TEMPLATE, version, version);
        Path destinationPath = targetDir.resolve("fabric-installer-" + version + ".jar");
        
        System.out.println("Fabric インストーラーをダウンロード中...");
        System.out.println("URL: " + url);
        System.out.println("保存先: " + destinationPath);
        
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url))
            .build();
            
        HttpResponse<Path> response = NetworkUtils.getHttpClient()
            .send(request, HttpResponse.BodyHandlers.ofFile(destinationPath));
        
        if (response.statusCode() != 200) {
            throw new RuntimeException("Fabric インストーラーのダウンロードに失敗しました。HTTP エラー: " + response.statusCode());
        }
        
        System.out.println("Fabric インストーラーのダウンロードが完了しました。");
        return response.body();
    }
    
    /**
     * Fabric インストーラーを実行します
     * @param javaExecutable Java 実行ファイルのパス
     * @param fabricJar Fabric インストーラー JAR ファイルのパス
     * @param minecraftVersion インストール対象の Minecraft バージョン
     * @return インストールされた Fabric Loader のバージョン
     * @throws Exception インストールエラー
     */
    public static String runFabricInstaller(Path javaExecutable, Path fabricJar, String minecraftVersion) throws Exception {
        System.out.println("Fabric インストーラーを実行中...");
        System.out.println("Java 実行ファイル: " + javaExecutable);
        System.out.println("Fabric インストーラー: " + fabricJar);
        System.out.println("Minecraft バージョン: " + minecraftVersion);
        
        ProcessBuilder processBuilder = new ProcessBuilder(
            javaExecutable.toString(),
            "-jar", fabricJar.toString(),
            "client",
            "-mcversion", minecraftVersion
        );
        
        processBuilder.redirectErrorStream(true);
        Process process = processBuilder.start();
        
        String loaderVersion = null;
        
        // Windows での文字化け対策：複数のエンコーディングを試行
        try (BufferedReader reader = createEncodingAwareReader(process)) {
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println("Fabric: " + line);
                
                // Fabric Loader バージョンを抽出
                if (line.matches(".*with fabric (\\d+\\.\\d+\\.\\d+).*") && loaderVersion == null) {
                    loaderVersion = line.replaceAll(".*with fabric (\\d+\\.\\d+\\.\\d+).*", "$1");
                    System.out.println("検出された Fabric Loader バージョン: " + loaderVersion);
                }
            }
        }
        
        int exitCode = process.waitFor();
        
        if (exitCode != 0) {
            throw new RuntimeException("Fabric インストーラーの実行に失敗しました。終了コード: " + exitCode);
        }
        
        if (loaderVersion == null) {
            throw new RuntimeException("Fabric Loader バージョンの取得に失敗しました。インストーラーの出力を確認してください。");
        }
        
        System.out.println("Fabric インストールが完了しました。Loader バージョン: " + loaderVersion);
        return loaderVersion;
    }
    
    /**
     * プロセスの出力ストリームから文字化けを防ぐ BufferedReader を作成します
     * @param process 実行中のプロセス
     * @return 適切なエンコーディングで設定された BufferedReader
     */
    private static BufferedReader createEncodingAwareReader(Process process) {
        try {
            // まず Shift_JIS を試す（Windows の日本語環境で一般的）
            return new BufferedReader(new InputStreamReader(process.getInputStream(), "Shift_JIS"));
        } catch (Exception e) {
            // Shift_JIS が利用できない場合はシステムデフォルトを使用
            String encoding = System.getProperty("file.encoding", "UTF-8");
            System.out.println("Shift_JIS が利用できないため、エンコーディング " + encoding + " を使用します。");
            try {
                return new BufferedReader(new InputStreamReader(process.getInputStream(), encoding));
            } catch (UnsupportedEncodingException ex) {
                // 最終的にはデフォルトエンコーディングで作成
                return new BufferedReader(new InputStreamReader(process.getInputStream()));
            }
        }
    }
}
