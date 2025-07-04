package com.abcd.modpack.utils;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import dev.dewy.nbt.Nbt;
import dev.dewy.nbt.tags.collection.CompoundTag;
import dev.dewy.nbt.tags.collection.ListTag;
import dev.dewy.nbt.tags.primitive.ByteTag;
import dev.dewy.nbt.tags.primitive.StringTag;

/**
 * ファイル操作のユーティリティクラス
 * ZIP展開、ファイル削除、パターンマッチングなどの機能を提供します
 */
public class FileUtils {
    
    /**
     * ZIP ファイルを指定されたディレクトリに展開します
     * @param zipFile 展開する ZIP ファイルのパス
     * @param destinationDir 展開先ディレクトリ
     * @throws IOException ファイル操作エラー
     */
    public static void unzip(Path zipFile, Path destinationDir) throws IOException {
        System.out.println("ZIP ファイルを展開中: " + zipFile);
        System.out.println("展開先: " + destinationDir);
        
        try (ZipInputStream zis = new ZipInputStream(Files.newInputStream(zipFile))) {
            ZipEntry entry;
            int extractedCount = 0;
            
            while ((entry = zis.getNextEntry()) != null) {
                Path outputPath = destinationDir.resolve(entry.getName());
                
                // セキュリティ対策: ディレクトリトラバーサル攻撃を防ぐ
                if (!outputPath.startsWith(destinationDir)) {
                    throw new IOException("ZIP エントリが展開先ディレクトリ外を指しています: " + entry.getName());
                }
                
                if (entry.isDirectory()) {
                    Files.createDirectories(outputPath);
                    System.out.println("ディレクトリ作成: " + outputPath);
                } else {
                    // 親ディレクトリが存在しない場合は作成
                    Files.createDirectories(outputPath.getParent());
                    Files.copy(zis, outputPath, StandardCopyOption.REPLACE_EXISTING);
                    extractedCount++;
                    
                    if (extractedCount % 10 == 0) {
                        System.out.println("展開済みファイル数: " + extractedCount);
                    }
                }
                
                zis.closeEntry();
            }
            
            System.out.println("ZIP ファイルの展開が完了しました。展開ファイル数: " + extractedCount);
        }
    }
    
    /**
     * 指定されたパターンに一致するファイルを削除します
     * @param baseDir 検索開始ディレクトリ
     * @param pattern ファイルパターン（ワイルドカードを含む可能性がある）
     * @throws IOException ファイル操作エラー
     */
    public static void removeFilesWithPattern(Path baseDir, String pattern) throws IOException {
        System.out.println("パターンに一致するファイルを削除中: " + pattern);
        System.out.println("検索ディレクトリ: " + baseDir);
        
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
            System.out.println("削除対象ディレクトリが見つかりません: " + searchDir);
            return;
        }
        
        // ワイルドカードパターンを正規表現に変換
        String regex = convertWildcardToRegex(fileName);
        Pattern filePattern = Pattern.compile(regex);
        
        // ディレクトリ内のファイルを検索して削除
        int deletedCount = 0;
        try (var stream = Files.list(searchDir)) {
            var filesToDelete = stream
                .filter(Files::isRegularFile)
                .filter(path -> filePattern.matcher(path.getFileName().toString()).matches())
                .toList(); // Java 16+ の toList() を使用
            
            for (Path path : filesToDelete) {
                try {
                    System.out.println("ファイルを削除: " + path);
                    Files.delete(path);
                    deletedCount++;
                } catch (IOException e) {
                    System.err.println("ファイル削除に失敗: " + path + " - " + e.getMessage());
                }
            }
        }
        
        System.out.println("削除完了。削除ファイル数: " + deletedCount);
    }
    
    /**
     * ワイルドカードパターンを正規表現に変換します
     * @param wildcardPattern ワイルドカードパターン (* や ? を含む)
     * @return 正規表現文字列
     */
    public static String convertWildcardToRegex(String wildcardPattern) {
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
    
    /**
     * ファイルが存在し、通常ファイルかどうかを確認します
     * @param filePath 確認するファイルのパス
     * @return ファイルが存在し、通常ファイルの場合は true
     */
    public static boolean isRegularFile(Path filePath) {
        return Files.exists(filePath) && Files.isRegularFile(filePath);
    }
    
    /**
     * ディレクトリが存在しない場合は作成します
     * @param dirPath 作成するディレクトリのパス
     * @throws IOException ディレクトリ作成エラー
     */
    public static void ensureDirectoryExists(Path dirPath) throws IOException {
        if (!Files.exists(dirPath)) {
            Files.createDirectories(dirPath);
            System.out.println("ディレクトリを作成しました: " + dirPath);
        }
    }
    
   /**
     * server.dat (NBT 形式) にサーバーエントリを含むかどうかを確認します。
     * @param serverDatPath server.dat のパス
     * @param address サーバーアドレス
     * @return サーバーエントリが存在する場合は true
     * 
     * servers.dat の構造:
     * {
     *   "servers": [
     *     {
     *       acceptTextures: 1
     *       hidden: 0
     *       ip: "mc.a-b-c-d.com"
     *       name: "A-B-C-D Server"
     *     }
     *   ]
     * }
     */
    public static boolean containsServerEntry(Path serverDatPath, String address) {
        try {
            if (!Files.exists(serverDatPath)) {
                return false;
            }
            
            // NBT ライブラリで servers.dat を読み込み
            Nbt nbt = new Nbt();
            CompoundTag root = nbt.fromFile(serverDatPath.toFile());

            // "servers" リストを取得
            if (!root.contains("servers")) {
                return false;
            }
            
            ListTag<CompoundTag> servers = root.getList("servers");
            if (servers == null) {
                return false;
            }
            
            // 各サーバーエントリの IP アドレスを確認
            for (CompoundTag server : servers) {
                if (server.contains("ip")) {
                    StringTag ipTag = server.getString("ip");
                    if (ipTag != null && address.equals(ipTag.getValue())) {
                        System.out.println("サーバーエントリが見つかりました: " + address);
                        return true;
                    }
                }
            }
            
            return false;
        } catch (IOException e) {
            System.err.println("servers.dat の読み込みに失敗しました: " + e.getMessage());
            return false;
        }
    }

    /**
     * servers.dat にサーバーエントリを追加します。
     * @param serverDatPath servers.dat のパス
     * @param address サーバーアドレス
     * @param name サーバー名
     */
    public static void addServerEntry(Path serverDatPath, String address, String name) {
        try {
            Nbt nbt = new Nbt();
            CompoundTag root;
            ListTag<CompoundTag> servers;
            
            // 既存の servers.dat ファイルを読み込むか、新規作成
            if (Files.exists(serverDatPath)) {
                root = nbt.fromFile(serverDatPath.toFile());
                
                // "servers" リストを取得または作成
                if (root.contains("servers")) {
                    servers = root.getList("servers");
                } else {
                    servers = new ListTag<>("servers");
                    root.put(servers);
                }
            } else {
                // 新規 servers.dat ファイルを作成
                root = new CompoundTag();
                servers = new ListTag<>("servers");
                root.put(servers);
                
                // 親ディレクトリが存在しない場合は作成
                Files.createDirectories(serverDatPath.getParent());
            }
            
            // 既にサーバーエントリが存在するかチェック
            boolean alreadyExists = false;
            for (CompoundTag server : servers) {
                if (server.contains("ip")) {
                    StringTag ipTag = server.getString("ip");
                    if (ipTag != null && address.equals(ipTag.getValue())) {
                        alreadyExists = true;
                        System.out.println("サーバーエントリは既に存在します: " + address);
                        break;
                    }
                }
            }
            
            // 存在しない場合は新しいサーバーエントリを追加
            if (!alreadyExists) {
                CompoundTag newServer = new CompoundTag();
                newServer.put(new StringTag("name", name));
                newServer.put(new StringTag("ip", address));
                newServer.put(new ByteTag("acceptTextures", (byte) 1));
                newServer.put(new ByteTag("hidden", (byte) 0));
                
                servers.add(newServer);
                
                // ファイルに保存
                nbt.toFile(root, serverDatPath.toFile());
                System.out.println("サーバーエントリを追加しました: " + name + " (" + address + ")");
            }
            
        } catch (IOException e) {
            System.err.println("servers.dat へのサーバー追加に失敗しました: " + e.getMessage());
        }
    }

    private static String findResourceFile(Path gameDir, String pattern) {
        // gameDir の resourcepacks ディレクトリをスキャンし、パターンにマッチするファイルを result に格納します
        try {
            return Files.list(gameDir.resolve("resourcepacks"))
                .filter(Files::isRegularFile)
                .map(Path::getFileName)
                .map(Path::toString)
                .filter(name -> name.matches(pattern))
                .map(name -> "file/" + name) // "file/" プレフィックスを追加
                .findFirst() // 最初に見つかったマッチを取得
                .orElse(null); // マッチがない場合は null を返す
        } catch (IOException e) {
            System.err.println("リソースパックのスキャン中にエラーが発生しました: " + e.getMessage());
            return null; // エラーが発生した場合は null を返す
        }
    }

    /**
     * options.txt ファイルを更新します。
     * @param gameDir ゲームディレクトリのパス
     * 
     * options.txt の設定項目：
version:4435
resourcePacks:["vanilla","fabric","file/Faithful-64x-Java-1.21.6.zip","file/AngelWing.zip"]
lang:ja_jp
skipMultiplayerWarning:true
joinedFirstServer:true
onboardAccessibility:false
key_key.saveToolbarActivator:key.keyboard.unknown
key_key.loadToolbarActivator:key.keyboard.unknown
key_key.quickActions:key.keyboard.unknown
soundCategory_master:0.1
     */
    public static void updateOptions(Path gameDir) {
        Path optionsFile = gameDir.resolve("options.txt");

        // 書き換えたい内容 options-modify.txt をリソースから読み込む
        InputStream inputStream = FileUtils.class.getResourceAsStream("/options-modify.txt");
        if (inputStream == null) {
            System.err.println("options-modify.txt がリソースに見つかりません。");
            return;
        }
        if (!Files.exists(optionsFile)) {
            System.out.println("options.txt が見つかりません。新規作成します: " + optionsFile);
            // inputStream を options.txt としてコピー
            try {
                Files.copy(inputStream, optionsFile, StandardCopyOption.REPLACE_EXISTING);
                System.out.println("新しい options.txt を作成しました: " + optionsFile);
            } catch (IOException e) {
                System.err.println("options.txt の作成に失敗しました: " + e.getMessage());
            }
            return;
        }
        
        // 
        // resourcePacks:["vanilla","fabric","file/Faithful-64x-Java-1.21.6.zip","file/AngelWing.zip"]
        //
        List<String> entries = new ArrayList<>();
        entries.add("vanilla");
        entries.add("fabric");
        // オーダーとしては、Faithful, AngelWing の順にする必要がある
        String faithfulPack = findResourceFile(gameDir, "Faithful.*\\.zip");
        if (faithfulPack != null) {
            entries.add(faithfulPack);
        }
        String angelWingPack = findResourceFile(gameDir, "AngelWing.*\\.zip");
        if (angelWingPack != null) {
            entries.add(angelWingPack);
        }
        String resourcePacks = "[" + entries.stream()
            .map(entry -> "\"" + entry + "\"") // 各要素をダブルクォートで囲む
            .collect(Collectors.joining(",")) + "]";

        // options.txt の内容を設定
        Map<String, String> dict = new java.util.HashMap<>();
        dict.put("resourcePacks", resourcePacks);
        dict.put("lang", "ja_jp");
        dict.put("skipMultiplayerWarning", "true");
        dict.put("joinedFirstServer", "true");
        dict.put("onboardAccessibility", "false");
        dict.put("key_key.saveToolbarActivator", "key.keyboard.unknown");
        dict.put("key_key.loadToolbarActivator", "key.keyboard.unknown");
        dict.put("key_key.quickActions", "key.keyboard.unknown");
        dict.put("soundCategory_master", "0.10264900662251655");
        
        // options.txt を１行ずつ読み込み
        // dict のキーが存在する場合は上書き、存在しない場合はそのまま書き込む
        try {
            List<String> lines = Files.readAllLines(optionsFile);
            List<String> newLines = new ArrayList<>();
            
            for (String line : lines) {
                String[] parts = line.split(":", 2);
                if (parts.length == 2 && dict.containsKey(parts[0])) {
                    // キーが存在する場合は上書き
                    newLines.add(parts[0] + ":" + dict.get(parts[0]));
                } else {
                    // キーが存在しない場合はそのまま追加
                    newLines.add(line);
                }
            }
            
            // 新しい内容を options.txt に書き込む
            Files.write(optionsFile, newLines);
            System.out.println("options.txt を更新しました: " + optionsFile);
        } catch (IOException e) {
            System.err.println("options.txt の更新に失敗しました: " + e.getMessage());
        }
    }
        
}
