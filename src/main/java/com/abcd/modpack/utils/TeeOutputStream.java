package com.abcd.modpack.utils;

import java.io.IOException;
import java.io.OutputStream;

/**
 * 複数の OutputStream に同時に出力を行う TeeOutputStream
 * Unix の tee コマンドと同様の機能を提供します
 */
public class TeeOutputStream extends OutputStream {
    private final OutputStream[] outputStreams;

    /**
     * 複数の OutputStream を受け取って同時出力を行う TeeOutputStream を作成します
     *
     * @param outputStreams 出力先の OutputStream 配列
     */
    public TeeOutputStream(OutputStream... outputStreams) {
        this.outputStreams = outputStreams;
    }

    @Override
    public void write(int b) throws IOException {
        IOException lastException = null;
        for (OutputStream outputStream : outputStreams) {
            try {
                outputStream.write(b);
            } catch (IOException e) {
                lastException = e;
                // エラーが発生しても他の出力ストリームへの書き込みを継続
            }
        }
        if (lastException != null) {
            throw lastException;
        }
    }

    @Override
    public void write(byte[] b) throws IOException {
        IOException lastException = null;
        for (OutputStream outputStream : outputStreams) {
            try {
                outputStream.write(b);
            } catch (IOException e) {
                lastException = e;
                // エラーが発生しても他の出力ストリームへの書き込みを継続
            }
        }
        if (lastException != null) {
            throw lastException;
        }
    }

    @Override
    public void write(byte[] b, int off, int len) throws IOException {
        IOException lastException = null;
        for (OutputStream outputStream : outputStreams) {
            try {
                outputStream.write(b, off, len);
            } catch (IOException e) {
                lastException = e;
                // エラーが発生しても他の出力ストリームへの書き込みを継続
            }
        }
        if (lastException != null) {
            throw lastException;
        }
    }

    @Override
    public void flush() throws IOException {
        IOException lastException = null;
        for (OutputStream outputStream : outputStreams) {
            try {
                outputStream.flush();
            } catch (IOException e) {
                lastException = e;
                // エラーが発生しても他の出力ストリームのフラッシュを継続
            }
        }
        if (lastException != null) {
            throw lastException;
        }
    }

    @Override
    public void close() throws IOException {
        IOException lastException = null;
        for (OutputStream outputStream : outputStreams) {
            try {
                outputStream.close();
            } catch (IOException e) {
                lastException = e;
                // エラーが発生しても他の出力ストリームのクローズを継続
            }
        }
        if (lastException != null) {
            throw lastException;
        }
    }
}
