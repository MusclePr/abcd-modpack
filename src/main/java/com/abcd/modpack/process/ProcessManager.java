package com.abcd.modpack.process;

import com.abcd.modpack.gui.GuiManager;

/**
 * プロセス管理を行うクラス
 * Minecraft や他のアプリケーションの実行状態を監視します
 */
public class ProcessManager {
    
    /**
     * Minecraft が実行中かどうかを確認します
     * @return Minecraft が実行中の場合は true
     */
    public static boolean isMinecraftRunning() {
        try {
            boolean isRunning = ProcessHandle.allProcesses()
                .anyMatch(ph -> ph.info().command()
                    .map(cmd -> cmd.toLowerCase().contains("minecraft"))
                    .orElse(false));
            
            if (isRunning) {
                System.out.println("Minecraft プロセスが実行中です。");
            } else {
                System.out.println("Minecraft プロセスは実行されていません。");
            }
            
            return isRunning;
        } catch (Exception e) {
            System.err.println("プロセス確認中にエラーが発生しました: " + e.getMessage());
            return false; // エラー時は安全側に倒して未実行として扱う
        }
    }
    
    /**
     * Minecraft の終了を待機します
     * ユーザーに終了を促すメッセージを表示し、プロセスが終了するまで待機します
     * @param guiManager GUI管理オブジェクト
     * @throws InterruptedException 待機が中断された場合
     */
    public static void waitForMinecraftExit(GuiManager guiManager) throws InterruptedException {
        while (isMinecraftRunning()) {
            System.out.println("Minecraft のランチャーを終了してください。");
            
            // GUI マネージャーがある場合は警告ダイアログを表示
            if (guiManager != null) {
                try {
                    guiManager.showWarningDialog("Minecraft のランチャーを終了してください。", "警告");
                } catch (Exception e) {
                    System.err.println("警告ダイアログの表示に失敗しました: " + e.getMessage());
                }
            }
            
            Thread.sleep(1000); // 1秒待機
        }
        
        System.out.println("Minecraft のランチャーが起動していない事を確認しました。");
    }
}
