package com.brian.easytrans.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class TranslateStreamRequest {

    @NotBlank(message = "翻译文本不能为空")
    @Size(max = 32000, message = "单次翻译文本过长")
    private String text;

    @NotBlank(message = "源语言不能为空")
    private String sourceLanguage;

    @NotBlank(message = "目标语言不能为空")
    private String targetLanguage;

    @NotBlank(message = "翻译样式不能为空")
    private String style;

    private String clientRequestId;

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    public String getSourceLanguage() {
        return sourceLanguage;
    }

    public void setSourceLanguage(String sourceLanguage) {
        this.sourceLanguage = sourceLanguage;
    }

    public String getTargetLanguage() {
        return targetLanguage;
    }

    public void setTargetLanguage(String targetLanguage) {
        this.targetLanguage = targetLanguage;
    }

    public String getStyle() {
        return style;
    }

    public void setStyle(String style) {
        this.style = style;
    }

    public String getClientRequestId() {
        return clientRequestId;
    }

    public void setClientRequestId(String clientRequestId) {
        this.clientRequestId = clientRequestId;
    }
}
