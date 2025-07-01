package com.abcd.modpack.gui;

import javax.swing.*;
import java.awt.*;
import java.io.OutputStream;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;

/**
 * GUI 関連の処理を管理するクラス
 * Swing ベースのコンソール出力ウィンドウを提供します
 */
public class GuiManager {
    private final JFrame frame;
    private final JTextArea textArea;
    
    /**
     * GUI マネージャーを初期化します
     */
    public GuiManager() {
        // コンソール出力のための親ウィンドウを作成
        frame = new JFrame("A-B-C-D Modpack Updater");
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setSize(800, 400);
        frame.setLocationRelativeTo(null); // 画面中央に配置
        frame.setAlwaysOnTop(true); // 常に最前面に表示
        frame.setVisible(false); // 初期表示は非表示
        
        // コンソール出力を表示するためのテキストエリア（日本語対応）
        textArea = new JTextArea();
        textArea.setEditable(false);
        textArea.setFont(new Font("Monospaced", Font.PLAIN, 14));
        textArea.setLineWrap(true);
        textArea.setWrapStyleWord(true);
        textArea.setCaretPosition(0); // 初期カーソル位置を先頭
        
        JScrollPane scrollPane = new JScrollPane(textArea);
        frame.getContentPane().add(scrollPane, BorderLayout.CENTER);
        
        // コンソール出力をテキストエリアにリダイレクト
        setupConsoleRedirection();
    }
    
    /**
     * コンソール出力をGUIにリダイレクトする設定を行います
     */
    private void setupConsoleRedirection() {
        PrintStream console = new PrintStream(new OutputStream() {
            @Override
            // UTF-8での文字化けを防ぐため、OutputStreamWriterを使用
            public void write(byte[] b, int off, int len) {
                String str = new String(b, off, len, StandardCharsets.UTF_8);
                SwingUtilities.invokeLater(() -> {
                    textArea.append(str);
                    textArea.setCaretPosition(textArea.getDocument().getLength()); // 常に最新の出力を表示
                });
            }
            
            public void write(int b) {
                SwingUtilities.invokeLater(() -> {
                    textArea.append(String.valueOf((char) b));
                    textArea.setCaretPosition(textArea.getDocument().getLength()); // 常に最新の出力を表示
                });
            }
        });
        
        System.setOut(console);
        System.setErr(console);
    }
    
    /**
     * GUI ウィンドウを表示します
     */
    public void showWindow() {
        SwingUtilities.invokeLater(() -> frame.setVisible(true));
    }
    
    /**
     * GUI ウィンドウを閉じます
     */
    public void closeWindow() {
        SwingUtilities.invokeLater(() -> frame.dispose());
    }
    
    /**
     * フレームオブジェクトを取得します
     * @return JFrame オブジェクト
     */
    public JFrame getFrame() {
        return frame;
    }
    
    /**
     * 情報メッセージダイアログを表示します（ブロッキング）
     * @param message 表示するメッセージ
     * @param title タイトル
     */
    public void showInfoDialog(String message, String title) {
        if (SwingUtilities.isEventDispatchThread()) {
            JOptionPane.showMessageDialog(frame, message, title, JOptionPane.INFORMATION_MESSAGE);
        } else {
            try {
                SwingUtilities.invokeAndWait(() -> 
                    JOptionPane.showMessageDialog(frame, message, title, JOptionPane.INFORMATION_MESSAGE)
                );
            } catch (Exception e) {
                System.err.println("情報ダイアログの表示に失敗しました: " + e.getMessage());
            }
        }
    }
    
    /**
     * 情報メッセージダイアログを非同期で表示します（ノンブロッキング）
     * @param message 表示するメッセージ
     * @param title タイトル
     */
    public void showInfoDialogAsync(String message, String title) {
        SwingUtilities.invokeLater(() -> 
            JOptionPane.showMessageDialog(frame, message, title, JOptionPane.INFORMATION_MESSAGE)
        );
    }
    
    /**
     * 警告メッセージダイアログを表示します（ブロッキング）
     * @param message 表示するメッセージ
     * @param title タイトル
     */
    public void showWarningDialog(String message, String title) {
        if (SwingUtilities.isEventDispatchThread()) {
            JOptionPane.showMessageDialog(frame, message, title, JOptionPane.WARNING_MESSAGE);
        } else {
            try {
                SwingUtilities.invokeAndWait(() -> 
                    JOptionPane.showMessageDialog(frame, message, title, JOptionPane.WARNING_MESSAGE)
                );
            } catch (Exception e) {
                System.err.println("警告ダイアログの表示に失敗しました: " + e.getMessage());
            }
        }
    }
    
    /**
     * 警告メッセージダイアログを非同期で表示します（ノンブロッキング）
     * @param message 表示するメッセージ
     * @param title タイトル
     */
    public void showWarningDialogAsync(String message, String title) {
        SwingUtilities.invokeLater(() -> 
            JOptionPane.showMessageDialog(frame, message, title, JOptionPane.WARNING_MESSAGE)
        );
    }
    
    /**
     * エラーメッセージダイアログを表示します（ブロッキング）
     * @param message 表示するメッセージ
     * @param title タイトル
     */
    public void showErrorDialog(String message, String title) {
        if (SwingUtilities.isEventDispatchThread()) {
            JOptionPane.showMessageDialog(frame, message, title, JOptionPane.ERROR_MESSAGE);
        } else {
            try {
                SwingUtilities.invokeAndWait(() -> 
                    JOptionPane.showMessageDialog(frame, message, title, JOptionPane.ERROR_MESSAGE)
                );
            } catch (Exception e) {
                System.err.println("エラーダイアログの表示に失敗しました: " + e.getMessage());
            }
        }
    }
    
    /**
     * エラーメッセージダイアログを非同期で表示します（ノンブロッキング）
     * @param message 表示するメッセージ
     * @param title タイトル
     */
    public void showErrorDialogAsync(String message, String title) {
        SwingUtilities.invokeLater(() -> 
            JOptionPane.showMessageDialog(frame, message, title, JOptionPane.ERROR_MESSAGE)
        );
    }
    
    /**
     * 確認ダイアログを表示します（ブロッキング）
     * @param message 表示するメッセージ
     * @param title タイトル
     * @return ユーザーの選択（YES_OPTION または NO_OPTION）
     */
    public int showConfirmDialog(String message, String title) {
        if (SwingUtilities.isEventDispatchThread()) {
            return JOptionPane.showConfirmDialog(
                frame, message, title, 
                JOptionPane.YES_NO_OPTION, 
                JOptionPane.QUESTION_MESSAGE
            );
        } else {
            final int[] result = new int[1];
            try {
                SwingUtilities.invokeAndWait(() -> {
                    result[0] = JOptionPane.showConfirmDialog(
                        frame, message, title, 
                        JOptionPane.YES_NO_OPTION, 
                        JOptionPane.QUESTION_MESSAGE
                    );
                });
                return result[0];
            } catch (Exception e) {
                System.err.println("確認ダイアログの表示に失敗しました: " + e.getMessage());
                return JOptionPane.NO_OPTION; // エラー時はNOを返す
            }
        }
    }
}
