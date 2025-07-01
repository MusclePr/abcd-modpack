package com.abcd.modpack.utils;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

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
}
