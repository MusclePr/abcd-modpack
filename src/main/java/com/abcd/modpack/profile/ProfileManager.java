package com.abcd.modpack.profile;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Minecraft ランチャープロファイルの管理を行うクラス
 * launcher_profiles.json の編集と A-B-C-D プロファイルの作成を提供します
 */
public class ProfileManager {
    private static final String PROFILE_ICON_BASE64 = 
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACABAMAAAAxEHz4AAAAGFBMVEUAAAA4NCrb0LTGvKW8spyAem2uppSakn5SsnMLAAAAAXRSTlMAQObYZgAAAJ5JREFUaIHt1MENgCAMRmFWYAVXcAVXcAVXcH3bhCYNkYjcKO8dSf7v1JASUWdZAlgb0PEmDSMAYYBdGkYApgf8ER3SbwRgesAf0RACMD1gB6S9IbkEEBfwY49oNj4lgLhA64C0o9R9RABTAvp4SX5kB2TA5y8EEAK4pRrxB9QcA4QBWkj3GCAMUCO/xwBhAI/kEsCagCHDY4AwAC3VA6t4zTAMj0OJAAAAAElFTkSuQmCC";
    
    private static final String JAVA_ARGS = 
        "-Xmx4G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 " +
        "-XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M";
    
    /**
     * Minecraft ランチャープロファイルを更新します
     * @param minecraftVersion Minecraft バージョン
     * @param loaderVersion Fabric Loader バージョン
     * @param gameDir ゲームディレクトリのパス
     * @throws Exception ファイル操作エラーまたは JSON 処理エラー
     */
    public static void updateLauncherProfiles(String minecraftVersion, String loaderVersion, Path gameDir) throws Exception {
        System.out.println("ランチャープロファイルを更新中...");
        System.out.println("Minecraft バージョン: " + minecraftVersion);
        System.out.println("Fabric Loader バージョン: " + loaderVersion);
        System.out.println("ゲームディレクトリ: " + gameDir);
        
        Path profilePath = getProfilePath();
        
        if (!Files.exists(profilePath)) {
            throw new RuntimeException("launcher_profiles.json が見つかりません: " + profilePath);
        }
        
        // 既存のプロファイルファイルを読み込み
        String jsonText = Files.readString(profilePath, StandardCharsets.UTF_8);
        System.out.println("既存のプロファイルファイルを読み込みました。");
        
        // 既存の A-B-C-D 関連プロファイルを削除
        jsonText = removeExistingProfiles(jsonText, minecraftVersion);
        
        // 新しいプロファイルを作成して追加
        String newProfile = createNewProfile(minecraftVersion, loaderVersion, gameDir);
        jsonText = addJsonProfile(jsonText, newProfile);
        
        // ファイルに書き戻し
        Files.writeString(profilePath, jsonText, StandardCharsets.UTF_8);
        System.out.println("ランチャープロファイルの更新が完了しました。");
    }
    
    /**
     * launcher_profiles.json のパスを取得します
     * @return プロファイルファイルのパス
     */
    private static Path getProfilePath() {
        return Paths.get(System.getenv("APPDATA"), ".minecraft", "launcher_profiles.json");
    }
    
    /**
     * 既存の A-B-C-D 関連プロファイルを削除します
     * @param jsonText 元の JSON テキスト
     * @param minecraftVersion Minecraft バージョン
     * @return 既存プロファイルが削除された JSON テキスト
     */
    private static String removeExistingProfiles(String jsonText, String minecraftVersion) {
        System.out.println("既存の A-B-C-D プロファイルを削除中...");
        
        // fabric-loader-{version} 形式のプロファイルキーを削除
        String fabricProfileKey = "\"fabric-loader-" + minecraftVersion + "\"";
        jsonText = removeJsonProfile(jsonText, fabricProfileKey);
        
        // A-B-C-D プロファイルキーを削除
        String abcdProfileKey = "\"A-B-C-D\"";
        jsonText = removeJsonProfile(jsonText, abcdProfileKey);
        
        System.out.println("既存プロファイルの削除が完了しました。");
        return jsonText;
    }
    
    /**
     * 新しい A-B-C-D プロファイルを作成します
     * @param minecraftVersion Minecraft バージョン
     * @param loaderVersion Fabric Loader バージョン
     * @param gameDir ゲームディレクトリ
     * @return 新しいプロファイルの JSON 文字列
     */
    private static String createNewProfile(String minecraftVersion, String loaderVersion, Path gameDir) {
        String profileId = "\"A-B-C-D\"";
        String created = Instant.now().toString();
        String gameDirEscaped = gameDir.toString().replace("\\", "\\\\");
        String versionId = "fabric-loader-" + loaderVersion + "-" + minecraftVersion;
        String profileName = "A-B-C-D " + minecraftVersion;
        
        return String.format(
            "    %s: {\n" +
            "      \"created\": \"%s\",\n" +
            "      \"gameDir\": \"%s\",\n" +
            "      \"icon\": \"%s\",\n" +
            "      \"javaArgs\": \"%s\",\n" +
            "      \"lastUsed\": \"%s\",\n" +
            "      \"lastVersionId\": \"%s\",\n" +
            "      \"name\": \"%s\",\n" +
            "      \"type\": \"custom\"\n" +
            "    }",
            profileId, created, gameDirEscaped, PROFILE_ICON_BASE64, 
            JAVA_ARGS, created, versionId, profileName
        );
    }
    
    /**
     * JSON から指定されたプロファイルキーを削除します
     * @param jsonText 元の JSON テキスト
     * @param profileKey 削除するプロファイルキー
     * @return プロファイルが削除された JSON テキスト
     */
    private static String removeJsonProfile(String jsonText, String profileKey) {
        // 指定されたプロファイルキーを含む行とその値を削除
        String regex = "\\s*" + Pattern.quote(profileKey) + ":\\s*\\{[^{}]*(?:\\{[^{}]*\\}[^{}]*)*\\},?\\s*";
        String result = jsonText.replaceAll(regex, "");
        
        if (!result.equals(jsonText)) {
            System.out.println("プロファイルを削除しました: " + profileKey);
        }
        
        return result;
    }
    
    /**
     * JSON の profiles セクションに新しいプロファイルを追加します
     * @param jsonText 元の JSON テキスト
     * @param newProfile 追加するプロファイルの JSON 文字列
     * @return 新しいプロファイルが追加された JSON テキスト
     */
    private static String addJsonProfile(String jsonText, String newProfile) {
        System.out.println("新しいプロファイルを追加中...");
        
        // "profiles" セクションを見つけて新しいプロファイルを追加
        String profilesPattern = "(\"profiles\"\\s*:\\s*\\{)";
        Matcher matcher = Pattern.compile(profilesPattern).matcher(jsonText);
        
        if (!matcher.find()) {
            throw new RuntimeException("launcher_profiles.json の profiles セクションが見つかりません。");
        }
        
        int insertPos = matcher.end();
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
        
        System.out.println("新しいプロファイルの追加が完了しました。");
        return beforeInsert + "\n" + toInsert + afterInsert;
    }
}
