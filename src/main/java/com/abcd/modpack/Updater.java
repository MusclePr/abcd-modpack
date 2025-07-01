package com.abcd.modpack;

import com.abcd.modpack.certificate.CertificateManager;
import com.abcd.modpack.fabric.FabricInstaller;
import com.abcd.modpack.gui.GuiManager;
import com.abcd.modpack.java.JavaDetector;
import com.abcd.modpack.modpack.ModpackProcessor;
import com.abcd.modpack.process.ProcessManager;
import com.abcd.modpack.profile.ProfileManager;
import com.abcd.modpack.utils.FileUtils;
import com.abcd.modpack.version.VersionManager;

import java.awt.Desktop;
import java.net.URI;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * A-B-C-D Modpack Updater のメインクラス
 * Minecraft modpack の自動更新とインストールを管理します
 */
public class Updater {
    public static void main(String[] args) throws Exception {
        // GUI マネージャーを初期化
        GuiManager guiManager = new GuiManager();
        guiManager.showWindow();

        try {
            // --uninstall-ca オプションの処理
            if (args.length > 0 && args[0].equals("--uninstall-ca")) {
                handleUninstallCA(guiManager);
                return;
            }

            // --version オプションの処理
            if (args.length > 0 && args[0].equals("--version")) {
                handleVersionDisplay(guiManager);
                return;
            }

            // --help オプションの処理
            if (args.length > 0 && args[0].equals("--help")) {
                handleHelpDisplay(guiManager);
                return;
            }

            // メインの更新処理を実行
            runMainUpdateProcess(guiManager);

        } catch (Exception e) {
            System.err.println("予期しないエラーが発生しました: " + e.getMessage());
            e.printStackTrace();
            guiManager.showErrorDialog("予期しないエラーが発生しました:\n" + e.getMessage(), "エラー");
        } catch (Throwable e) {
            System.err.println("予期しないエラーが発生しました: " + e.getMessage());
            e.printStackTrace();
            guiManager.showErrorDialog("予期しないエラーが発生しました:\n" + e.getMessage(), "エラー");
        } finally {
            //guiManager.showInfoDialog("終了します", "通知");
            // 処理完了後にウィンドウを閉じる
            guiManager.closeWindow();
        }
    }

    /**
     * CA 証明書のアンインストールを処理します
     */
    private static void handleUninstallCA(GuiManager guiManager) {
        System.out.println("CA証明書のアンインストールを実行します。");
        CertificateManager.uninstallCACertificate(guiManager);
    }

    /**
     * バージョン情報の表示を処理します
     */
    private static void handleVersionDisplay(GuiManager guiManager) {
        VersionManager versionManager = new VersionManager();
        System.out.println("A-B-C-D Modpack Updater");
        System.out.println("バージョン: " + versionManager.getCurrentVersion());
        System.out.println("開発元: A-B-C-D プロジェクト");
        System.out.println("ウェブサイト: https://a-b-c-d.com/");
        
        guiManager.showInfoDialog(
            "A-B-C-D Modpack Updater\n" +
            "バージョン: " + versionManager.getCurrentVersion() + "\n" +
            "開発元: A-B-C-D プロジェクト\n" +
            "ウェブサイト: https://a-b-c-d.com/",
            "バージョン情報"
        );
    }

    /**
     * ヘルプ情報の表示を処理します
     */
    private static void handleHelpDisplay(GuiManager guiManager) {
        System.out.println("A-B-C-D Modpack Updater - 使用方法");
        System.out.println("");
        System.out.println("使用法:");
        System.out.println("  java -jar abcd-modpack-updater.jar [オプション]");
        System.out.println("");
        System.out.println("オプション:");
        System.out.println("  --help          このヘルプを表示");
        System.out.println("  --version       バージョン情報を表示");
        System.out.println("  --uninstall-ca  CA証明書をアンインストール");
        System.out.println("");
        System.out.println("オプションを指定しない場合は通常の更新処理を実行します。");
        
        guiManager.showInfoDialog(
            "A-B-C-D Modpack Updater - 使用方法\n\n" +
            "使用法:\n" +
            "  java -jar abcd-modpack-updater.jar [オプション]\n\n" +
            "オプション:\n" +
            "  --help          このヘルプを表示\n" +
            "  --version       バージョン情報を表示\n" +
            "  --uninstall-ca  CA証明書をアンインストール\n\n" +
            "オプションを指定しない場合は通常の更新処理を実行します。",
            "ヘルプ"
        );
    }

    /**
     * メインの更新処理を実行します
     */
    private static void runMainUpdateProcess(GuiManager guiManager) throws Exception {
        System.out.println("A-B-C-D Modpack Updater を開始します...");

        // 1. バージョン確認
        VersionManager versionManager = new VersionManager();
        versionManager.fetchLatestVersionInfo();

        if (versionManager.isUpdateRequired()) {
            String message = versionManager.generateUpdateMessage();
            System.out.println(message);
            guiManager.showInfoDialog(message, "通知");
            
            // 既定のブラウザを起動
            Desktop.getDesktop().browse(URI.create("https://a-b-c-d.com/modpacks/#arkb-toc-1"));
            return;
        }

        // 2. 作業ディレクトリの作成
        Path gameDir = Paths.get(System.getenv("APPDATA"), ".minecraft_abcd");
        FileUtils.ensureDirectoryExists(gameDir);
        System.out.println("作業ディレクトリ: " + gameDir);

        // 3. Minecraft プロセスの確認
        ProcessManager.waitForMinecraftExit(guiManager);

        // 4. Java 実行ファイルの検出
        Path javaExe = JavaDetector.detectJava();
        if (javaExe == null) {
            String errorMessage = "Java 実行ファイルが見つかりません。\n" +
                "Minecraft Java Edition または Java Development Kit (JDK) をインストールしてください。";
            System.err.println(errorMessage);
            guiManager.showErrorDialog(errorMessage, "Java 実行環境エラー");
            return;
        }

        // 5. Fabric インストーラーの取得と実行
        String fabricVersion = FabricInstaller.fetchLatestFabricVersion();
        Path fabricJar = FabricInstaller.downloadFabricInstaller(gameDir, fabricVersion);
        String loaderVersion = FabricInstaller.runFabricInstaller(javaExe, fabricJar, versionManager.getMinecraftVersion());

        // 6. ランチャープロファイルの更新
        ProfileManager.updateLauncherProfiles(versionManager.getMinecraftVersion(), loaderVersion, gameDir);

        // 7. Modpack リストの処理
        ModpackProcessor.processModpackList(gameDir, versionManager.getMinecraftVersion());

        // 8. NBTファイルの servers.dat に mc.a-b-c-d.com へのサーバーが無ければ追加
        Path serverDatPath = gameDir.resolve("servers.dat");
        if (!FileUtils.containsServerEntry(serverDatPath, "mc.a-b-c-d.com")) {
            FileUtils.addServerEntry(serverDatPath, "mc.a-b-c-d.com", "A-B-C-D Server");
            System.out.println("サーバーエントリを server.dat に追加しました: mc.a-b-c-d.com");
        } else {
            System.out.println("servers.dat に既に mc.a-b-c-d.com のサーバーエントリが存在します。");
        }

        // 9. options.txt の更新
        FileUtils.updateOptions(gameDir);

        // 10. CA 証明書の確認とインストール
        CertificateManager.checkAndInstallCACertificate(guiManager);

        // 12. 完了メッセージ
        String completionMessage = "正常に完了しました。マインクラフトのランチャーを起動します。起動構成「A-B-C-D " + 
            versionManager.getMinecraftVersion() + "」から起動してください。";
        System.out.println(completionMessage);
        guiManager.showInfoDialog(completionMessage, "通知");

        // 13. ランチャーの起動
        new ProcessBuilder("explorer.exe", "shell:AppsFolder\\Microsoft.4297127D64EC6_8wekyb3d8bbwe!Minecraft").start();

    }
}
