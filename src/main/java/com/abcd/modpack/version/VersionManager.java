package com.abcd.modpack.version;

import com.abcd.modpack.network.NetworkUtils;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * バージョン管理を行うクラス
 * アプリケーションバージョンの取得と最新バージョンとの比較を提供します
 */
public class VersionManager {
    private static final String DEFAULT_VERSION = "0.0-SNAPSHOT";
    private static final String VERSION_URL = "https://a-b-c-d.com/downloads/abcd-mods-latest.txt";
    
    private String currentVersion;
    private String latestVersion;
    private String minecraftVersion;
    
    /**
     * バージョン管理を初期化します
     */
    public VersionManager() {
        loadCurrentVersion();
    }
    
    /**
     * 現在のアプリケーションバージョンを取得します
     * @return 現在のバージョン
     */
    public String getCurrentVersion() {
        return currentVersion;
    }
    
    /**
     * 最新のアプリケーションバージョンを取得します
     * @return 最新のバージョン
     */
    public String getLatestVersion() {
        return latestVersion;
    }
    
    /**
     * Minecraft バージョンを取得します
     * @return Minecraft バージョン
     */
    public String getMinecraftVersion() {
        return minecraftVersion;
    }
    
    /**
     * pom.properties からアプリケーションの現在のバージョンを読み込みます
     */
    private void loadCurrentVersion() {
        currentVersion = DEFAULT_VERSION;
        
        try (InputStream inputStream = VersionManager.class.getResourceAsStream("/META-INF/maven/com.abcd/abcd-modpack/pom.properties")) {
            if (inputStream != null) {
                System.out.println("pom.properties の読み込みに成功しました。");
                Properties props = new Properties();
                props.load(inputStream);
                currentVersion = props.getProperty("version", DEFAULT_VERSION);
            } else {
                System.out.println("pom.properties が見つかりません。デフォルトバージョンを使用します。");
            }
        } catch (IOException e) {
            System.err.println("pom.properties の読み込みに失敗しました: " + e.getMessage());
        }
        
        System.out.println("A-B-C-D Modpack Updater v" + currentVersion);
    }
    
    /**
     * サーバーから最新バージョン情報を取得します
     * @throws Exception ネットワークエラーまたはデータ解析エラー
     */
    public void fetchLatestVersionInfo() throws Exception {
        System.out.println("最新バージョン情報を取得中...");
        
        // 最新バージョン取得
        // １行目：マイクラバージョン
        // ２行目：アップデーターバージョン
        String text = NetworkUtils.fetchText(VERSION_URL);
        String[] lines = text.split(text.contains("\r\n") ? "\r\n" : "\n");
        
        if (lines.length < 2) {
            throw new RuntimeException("最新バージョン情報の取得に失敗しました。サーバーレスポンスが不正です。");
        }
        
        minecraftVersion = lines[0].trim();
        latestVersion = lines[1].trim();
        
        System.out.println("Minecraft Version: " + minecraftVersion);
        System.out.println("Latest Version: " + latestVersion);
    }
    
    /**
     * バージョンアップが必要かどうかを確認します
     * @return アップデートが必要な場合は true
     */
    public boolean isUpdateRequired() {
        if (latestVersion == null) {
            System.err.println("警告: 最新バージョン情報が取得されていません。");
            return false;
        }
        
        boolean updateRequired = !currentVersion.equals(latestVersion);
        
        if (updateRequired) {
            System.out.println("バージョンアップが必要です:");
            System.out.println("  現在のバージョン: " + currentVersion);
            System.out.println("  最新バージョン: " + latestVersion);
        } else {
            System.out.println("バージョンは最新です: " + currentVersion);
        }
        
        return updateRequired;
    }
    
    /**
     * アップデート案内メッセージを生成します
     * @return アップデート案内メッセージ
     */
    public String generateUpdateMessage() {
        return "A-B-C-D Modpack Updater のバージョンが古いです。\n" +
               "現在のバージョン: " + currentVersion + "\n" +
               "最新バージョン: " + latestVersion + "\n" +
               "アップデートを行ってください。\n" +
               "https://a-b-c-d.com/modpacks/";
    }
}
