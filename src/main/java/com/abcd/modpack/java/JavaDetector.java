package com.abcd.modpack.java;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Java 実行環境の検出を行うクラス
 * システム内の適切な Java 実行ファイルを自動検出します
 */
public class JavaDetector {
    
    /**
     * システム内の Java 実行ファイルを検出します
     * Microsoft Store 版 Minecraft の Java と JAVA_HOME を順番に確認します
     * 
     * @return Java 実行ファイルのパス。見つからない場合は null
     */
    public static Path detectJava() {
        System.out.println("Java 実行環境を検出中...");
        
        // 1. Microsoft Store 版 Minecraft 付属の Java を確認
        Path msJava = detectMicrosoftStoreJava();
        if (msJava != null) {
            System.out.println("Microsoft Store 版 Minecraft の Java を検出しました: " + msJava);
            return msJava;
        }
        
        // 2. JAVA_HOME 環境変数の Java を確認
        Path javaHomeJava = detectJavaHomeJava();
        if (javaHomeJava != null) {
            System.out.println("JAVA_HOME の Java を検出しました: " + javaHomeJava);
            return javaHomeJava;
        }
        
        // 3. システム PATH の java コマンドを確認（補助的）
        Path systemJava = detectSystemJava();
        if (systemJava != null) {
            System.out.println("システム PATH の Java を検出しました: " + systemJava);
            return systemJava;
        }
        
        System.err.println("Java 実行ファイルが見つかりませんでした。");
        System.err.println("以下のいずれかを確認してください:");
        System.err.println("  1. Minecraft Java Edition がインストールされているか");
        System.err.println("  2. JAVA_HOME 環境変数が正しく設定されているか");
        System.err.println("  3. Java Development Kit (JDK) がインストールされているか");
        
        return null;
    }
    
    /**
     * Microsoft Store 版 Minecraft 付属の Java を検出します
     * @return Java 実行ファイルのパス。見つからない場合は null
     */
    private static Path detectMicrosoftStoreJava() {
        try {
            String localAppData = System.getenv("LOCALAPPDATA");
            if (localAppData == null) {
                return null;
            }
            
            Path msJavaPath = Paths.get(
                localAppData,
                "Packages",
                "Microsoft.4297127D64EC6_8wekyb3d8bbwe",
                "LocalCache",
                "Local",
                "runtime",
                "java-runtime-delta",
                "windows-x64",
                "java-runtime-delta",
                "bin",
                "java.exe"
            );
            
            if (Files.exists(msJavaPath)) {
                return msJavaPath;
            }
            
            System.out.println("Microsoft Store 版の Java は見つかりませんでした。");
        } catch (Exception e) {
            System.err.println("Microsoft Store 版 Java の検出中にエラーが発生しました: " + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * JAVA_HOME 環境変数で指定された Java を検出します
     * @return Java 実行ファイルのパス。見つからない場合は null
     */
    private static Path detectJavaHomeJava() {
        try {
            String javaHome = System.getenv("JAVA_HOME");
            if (javaHome == null || javaHome.trim().isEmpty()) {
                System.out.println("JAVA_HOME 環境変数が設定されていません。");
                return null;
            }
            
            Path javaHomeExe = Paths.get(javaHome, "bin", "java.exe");
            if (Files.exists(javaHomeExe)) {
                return javaHomeExe;
            }
            
            System.out.println("JAVA_HOME の Java 実行ファイルが見つかりません: " + javaHomeExe);
        } catch (Exception e) {
            System.err.println("JAVA_HOME Java の検出中にエラーが発生しました: " + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * システム PATH の java コマンドを検出します（Windows環境での補助的な検出）
     * @return Java 実行ファイルのパス。見つからない場合は null
     */
    private static Path detectSystemJava() {
        try {
            // Windows の where コマンドを使用して java.exe を検索
            ProcessBuilder pb = new ProcessBuilder("where", "java.exe");
            Process process = pb.start();
            
            try (var reader = new java.io.BufferedReader(new java.io.InputStreamReader(process.getInputStream()))) {
                String line = reader.readLine();
                if (line != null && !line.trim().isEmpty()) {
                    Path javaPath = Paths.get(line.trim());
                    if (Files.exists(javaPath)) {
                        return javaPath;
                    }
                }
            }
            
            process.waitFor();
        } catch (Exception e) {
            System.err.println("システム Java の検出中にエラーが発生しました: " + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * 指定された Java 実行ファイルのバージョンを確認します
     * @param javaPath Java 実行ファイルのパス
     * @return Java バージョン文字列。取得に失敗した場合は null
     */
    public static String getJavaVersion(Path javaPath) {
        try {
            ProcessBuilder pb = new ProcessBuilder(javaPath.toString(), "-version");
            Process process = pb.start();
            
            try (var reader = new java.io.BufferedReader(new java.io.InputStreamReader(process.getErrorStream()))) {
                String line = reader.readLine();
                if (line != null) {
                    return line;
                }
            }
            
            process.waitFor();
        } catch (Exception e) {
            System.err.println("Java バージョンの取得に失敗しました: " + e.getMessage());
        }
        
        return null;
    }
}
