package com.abcd.modpack.network;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

/**
 * ネットワーク処理のユーティリティクラス
 * HTTP通信や外部リソースのダウンロードを提供します
 */
public class NetworkUtils {
    private static final HttpClient httpClient = HttpClient.newHttpClient();
    
    /**
     * 指定されたURLからテキストデータを取得します
     * @param url 取得先のURL
     * @return 取得されたテキストデータ
     * @throws Exception ネットワークエラーまたはHTTPエラー
     */
    public static String fetchText(String url) throws Exception {
        System.out.println("テキストデータを取得中: " + url);
        
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(url))
            .build();
            
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        
        if (response.statusCode() != 200) {
            throw new RuntimeException("HTTP エラー: " + response.statusCode() + " - " + url);
        }
        
        System.out.println("テキストデータの取得が完了しました。");
        return response.body();
    }
    
    /**
     * HTTPクライアントインスタンスを取得します
     * @return HttpClient インスタンス
     */
    public static HttpClient getHttpClient() {
        return httpClient;
    }
}
