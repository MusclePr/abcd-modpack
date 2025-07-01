package com.abcd.modpack.certificate;

import com.abcd.modpack.gui.GuiManager;

import javax.swing.JOptionPane;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.concurrent.TimeUnit;

/**
 * CA 証明書の管理を行うクラス
 * 証明書のインストール、アンインストール、確認機能を提供します
 */
public class CertificateManager {
    private static final String CA_CERTIFICATE_SUBJECT = "ABCD Development CA";
    private static final String CA_CERTIFICATE_RESOURCE_PATH = "/ca-certificate.pem";
    private static final String DEV_CERTIFICATE_PATH = "certificates/ca-certificate.pem";
    private static final int POWERSHELL_TIMEOUT_SECONDS = 5;
    
    /**
     * CA 証明書の確認とインストールを行います
     * @param guiManager GUI マネージャー
     */
    public static void checkAndInstallCACertificate(GuiManager guiManager) {
        try {
            System.out.println("CA証明書の確認を開始します...");
            
            // CA 証明書のパスを取得
            Path certPath = getCACertificatePath();
            if (certPath == null || !Files.exists(certPath)) {
                System.out.println("CA証明書ファイルが見つかりません。");
                return;
            }
            
            System.out.println("CA証明書ファイルが見つかりました: " + certPath);
            
            // 証明書がインストール済みかチェック
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
            if (showInstallConfirmDialog(guiManager)) {
                installCACertificate(certPath, guiManager);
            } else {
                System.out.println("CA証明書のインストールをスキップしました。");
            }
            
        } catch (Exception e) {
            System.err.println("CA証明書の処理中にエラーが発生しました: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * CA 証明書をアンインストールします
     * @param guiManager GUI マネージャー
     */
    public static void uninstallCACertificate(GuiManager guiManager) {
        try {
            System.out.println("CA証明書をアンインストールしています...");
            
            // PowerShell コマンドで証明書をアンインストール
            ProcessBuilder pb = new ProcessBuilder(
                "powershell.exe", "-Command",
                "Get-ChildItem Cert:\\LocalMachine\\Root | Where-Object {$_.Subject -match '" + CA_CERTIFICATE_SUBJECT + "'} | Remove-Item"
            );
            
            Process process = pb.start();
            
            // 出力を読み取り
            readProcessOutput(process, "PowerShell");
            
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                System.out.println("CA証明書のアンインストールが完了しました。");
                if (guiManager != null) {
                    guiManager.showInfoDialog("CA証明書のアンインストールが完了しました。", "証明書アンインストール完了");
                }
            } else {
                System.err.println("CA証明書のアンインストールに失敗しました。終了コード: " + exitCode);
                if (guiManager != null) {
                    guiManager.showErrorDialog("CA証明書のアンインストールに失敗しました。\n管理者権限で実行してください。", "証明書アンインストール失敗");
                }
            }
            
        } catch (Exception e) {
            System.err.println("CA証明書のアンインストール中にエラーが発生しました: " + e.getMessage());
            if (guiManager != null) {
                guiManager.showErrorDialog("CA証明書のアンインストール中にエラーが発生しました:\n" + e.getMessage(), "エラー");
            }
        }
    }
    
    /**
     * CA 証明書ファイルのパスを取得します
     * @return 証明書ファイルのパス。見つからない場合は null
     */
    private static Path getCACertificatePath() {
        try {
            // JAR ファイル内の ca-certificate.pem を一時ファイルにコピー
            InputStream certStream = CertificateManager.class.getResourceAsStream(CA_CERTIFICATE_RESOURCE_PATH);
            if (certStream != null) {
                Path tempCert = Files.createTempFile("ca-certificate", ".pem");
                Files.copy(certStream, tempCert, StandardCopyOption.REPLACE_EXISTING);
                certStream.close();
                return tempCert;
            }
        } catch (IOException e) {
            System.err.println("JARファイル内からCA証明書を読み込めませんでした: " + e.getMessage());
        }
        
        // JAR ファイル内にない場合は、開発環境のパスを試す
        Path devCertPath = Paths.get(DEV_CERTIFICATE_PATH);
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
    
    /**
     * CA 証明書がインストール済みかどうかを確認します
     * @return インストール済みの場合は true
     */
    private static boolean isCACertificateInstalled() {
        try {
            System.out.println("証明書ストアを確認中...");
            
            // PowerShell コマンドで証明書ストアを確認
            ProcessBuilder pb = new ProcessBuilder(
                "powershell.exe", "-ExecutionPolicy", "Bypass", "-Command",
                "(Get-ChildItem Cert:\\LocalMachine\\Root | Where-Object {$_.Subject -match '" + CA_CERTIFICATE_SUBJECT + "'}).Count"
            );
            pb.redirectErrorStream(true);
            Process process = pb.start();
            
            System.out.println("PowerShellプロセスを開始しました...");
            
            String output = "";
            
            // 短いタイムアウトで読み取り
            boolean finished = process.waitFor(POWERSHELL_TIMEOUT_SECONDS, TimeUnit.SECONDS);
            if (!finished) {
                System.err.println("PowerShellコマンドがタイムアウトしました。証明書チェックをスキップします。");
                process.destroyForcibly();
                return false; // タイムアウト時は未インストールとして扱う
            }
            
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output += line.trim();
                    System.out.println("PowerShell出力: " + line);
                }
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
    
    /**
     * CA 証明書をインストールします
     * @param certPath 証明書ファイルのパス
     * @param guiManager GUI マネージャー
     */
    private static void installCACertificate(Path certPath, GuiManager guiManager) {
        try {
            System.out.println("CA証明書をインストールしています...");
            
            // PowerShell コマンドで証明書をインストール
            ProcessBuilder pb = new ProcessBuilder(
                "powershell.exe", "-Command",
                "Import-Certificate -FilePath '" + certPath.toString() + "' -CertStoreLocation Cert:\\LocalMachine\\Root"
            );
            
            Process process = pb.start();
            
            // 出力を読み取り
            readProcessOutput(process, "PowerShell");
            
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                System.out.println("CA証明書のインストールが完了しました。");
                if (guiManager != null) {
                    guiManager.showInfoDialog("CA証明書のインストールが完了しました。", "証明書インストール完了");
                }
            } else {
                System.err.println("CA証明書のインストールに失敗しました。終了コード: " + exitCode);
                if (guiManager != null) {
                    guiManager.showErrorDialog("CA証明書のインストールに失敗しました。\n管理者権限で実行してください。", "証明書インストール失敗");
                }
            }
            
        } catch (Exception e) {
            System.err.println("CA証明書のインストール中にエラーが発生しました: " + e.getMessage());
            if (guiManager != null) {
                guiManager.showErrorDialog("CA証明書のインストール中にエラーが発生しました:\n" + e.getMessage(), "エラー");
            }
        }
    }
    
    /**
     * プロセスの出力を読み取って表示します
     * @param process 実行中のプロセス
     * @param prefix 出力プレフィックス
     * @throws IOException 入出力エラー
     */
    private static void readProcessOutput(Process process, String prefix) throws IOException {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
             BufferedReader errorReader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
            
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println(prefix + ": " + line);
            }
            
            while ((line = errorReader.readLine()) != null) {
                System.err.println(prefix + " Error: " + line);
            }
        }
    }
    
    /**
     * インストール確認ダイアログを表示します
     * @param guiManager GUI マネージャー
     * @return ユーザーがインストールを選択した場合は true
     */
    private static boolean showInstallConfirmDialog(GuiManager guiManager) {
        if (guiManager != null) {
            int result = guiManager.showConfirmDialog(
                CA_CERTIFICATE_SUBJECT + "証明書がインストールされていません。\n" +
                "セキュリティ警告を回避するためにインストールしますか？\n" +
                "（管理者権限が必要な場合があります）",
                "CA証明書のインストール"
            );
            return result == JOptionPane.YES_OPTION;
        }
        return false;
    }
}
