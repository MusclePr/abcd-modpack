package com.abcd.modpack.modpack;

import com.abcd.modpack.network.NetworkUtils;
import com.abcd.modpack.utils.FileUtils;

import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

/**
 * Modpack の処理を管理するクラス
 * Modpack リストのダウンロード、mod ファイルの管理、不要ファイルの削除を提供します
 */
public class ModpackProcessor {
    private static final String DOWNLOAD_BASE_URL = "https://a-b-c-d.com/downloads/";
    
    /**
     * Modpack リストを処理します
     * @param gameDir ゲームディレクトリ
     * @param minecraftVersion Minecraft バージョン
     * @throws Exception ネットワークエラーまたはファイル処理エラー
     */
    public static void processModpackList(Path gameDir, String minecraftVersion) throws Exception {
        System.out.println("Modpack リストの処理を開始します...");
        System.out.println("ゲームディレクトリ: " + gameDir);
        System.out.println("Minecraft バージョン: " + minecraftVersion);
        
        // パック定義ファイルをダウンロード
        String packsFileName = "abcd-update-packs-" + minecraftVersion + ".txt";
        Path packsPath = downloadPacksList(gameDir, packsFileName);
        
        // パック定義ファイルを読み込んで処理
        List<String> lines = Files.readAllLines(packsPath, StandardCharsets.UTF_8);
        
        int processedCount = 0;
        for (String line : lines) {
            if (line.isEmpty() || line.startsWith("#")) {
                // 空行やコメント行をスキップ
                continue;
            }
            
            System.out.println("処理中: " + line);
            
            if (line.length() < 2) {
                System.err.println("警告: 無効な行をスキップしました: " + line);
                continue;
            }
            
            char operation = line.charAt(0);
            String value = line.substring(1);
            
            switch (operation) {
                case '-':
                    // ファイル削除
                    removeFiles(gameDir, value);
                    break;
                    
                case '+':
                    // ファイルダウンロード
                    downloadAndProcessFile(gameDir, value);
                    break;
                    
                default:
                    System.err.println("警告: 不明な操作をスキップしました: " + line);
                    break;
            }
            
            processedCount++;
            
            if (processedCount % 5 == 0) {
                System.out.println("処理済み行数: " + processedCount);
            }
        }
        
        System.out.println("Modpack リストの処理が完了しました。処理総数: " + processedCount);
    }
    
    /**
     * Modpack リスト定義ファイルをダウンロードします
     * @param gameDir ゲームディレクトリ
     * @param fileName ダウンロードするファイル名
     * @return ダウンロードされたファイルのパス
     * @throws Exception ダウンロードエラー
     */
    private static Path downloadPacksList(Path gameDir, String fileName) throws Exception {
        Path packsPath = gameDir.resolve(fileName);
        
        // 既存ファイルがあれば削除
        Files.deleteIfExists(packsPath);
        
        System.out.println("Modpack リストをダウンロード中: " + fileName);
        
        String url = DOWNLOAD_BASE_URL + fileName;
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url))
            .build();
            
        HttpResponse<Path> response = NetworkUtils.getHttpClient()
            .send(request, HttpResponse.BodyHandlers.ofFile(packsPath));
        
        if (response.statusCode() != 200) {
            throw new RuntimeException("Modpack リストのダウンロードに失敗しました。HTTP エラー: " + response.statusCode());
        }
        
        System.out.println("Modpack リストのダウンロードが完了しました: " + packsPath);
        return packsPath;
    }
    
    /**
     * 指定されたパターンに一致するファイルを削除します
     * @param gameDir ゲームディレクトリ
     * @param pattern 削除対象のファイルパターン
     */
    private static void removeFiles(Path gameDir, String pattern) {
        try {
            System.out.println("ファイル削除: " + pattern);
            FileUtils.removeFilesWithPattern(gameDir, pattern);
        } catch (Exception e) {
            System.err.println("ファイル削除中にエラーが発生しました: " + pattern + " - " + e.getMessage());
        }
    }
    
    /**
     * ファイルをダウンロードして、必要に応じて展開します
     * @param gameDir ゲームディレクトリ
     * @param fileName ダウンロードするファイル名
     * @throws Exception ダウンロードエラーまたは展開エラー
     */
    private static void downloadAndProcessFile(Path gameDir, String fileName) throws Exception {
        System.out.println("ファイルダウンロード: " + fileName);
        
        String url = DOWNLOAD_BASE_URL + fileName;
        Path outputFile = gameDir.resolve(fileName);
        
        // 親ディレクトリが存在しない場合は作成
        FileUtils.ensureDirectoryExists(outputFile.getParent());
        
        // ファイルをダウンロード
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url))
            .build();
            
        HttpResponse<Path> response = NetworkUtils.getHttpClient()
            .send(request, HttpResponse.BodyHandlers.ofFile(outputFile));
        
        if (response.statusCode() != 200) {
            throw new RuntimeException("ファイルのダウンロードに失敗しました: " + fileName + " (HTTP エラー: " + response.statusCode() + ")");
        }
        
        System.out.println("ダウンロード完了: " + outputFile);
        
        // ZIP ファイルの場合は展開
        String fileExtension = getFileExtension(fileName);
        if (".zip".equalsIgnoreCase(fileExtension)) {
            System.out.println("ZIP ファイルを展開中: " + outputFile);
            FileUtils.unzip(outputFile, gameDir);
            
            // 展開後に ZIP ファイルを削除
            Files.deleteIfExists(outputFile);
            System.out.println("ZIP ファイルを削除しました: " + outputFile);
        }
    }
    
    /**
     * ファイル名から拡張子を取得します
     * @param fileName ファイル名
     * @return ファイル拡張子（ドット含む）。拡張子がない場合は空文字列
     */
    private static String getFileExtension(String fileName) {
        int lastDotIndex = fileName.lastIndexOf('.');
        if (lastDotIndex > 0 && lastDotIndex < fileName.length() - 1) {
            return fileName.substring(lastDotIndex);
        }
        return "";
    }
}
