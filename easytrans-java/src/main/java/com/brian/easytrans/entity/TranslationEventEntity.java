package com.brian.easytrans.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.brian.easytrans.entity.base.BaseEntity;

@TableName("translation_event")
public class TranslationEventEntity extends BaseEntity {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private String userId;

    @TableField("request_id")
    private String requestId;

    @TableField("client_request_id")
    private String clientRequestId;

    @TableField("source_lang")
    private String sourceLang;

    @TableField("target_lang")
    private String targetLang;

    @TableField
    private String style;

    @TableField("input_chars")
    private Integer inputChars;

    @TableField("output_chars")
    private Integer outputChars;

    @TableField("duration_ms")
    private Long durationMs;

    @TableField
    private String status;

    @TableField("error_message")
    private String errorMessage;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getRequestId() {
        return requestId;
    }

    public void setRequestId(String requestId) {
        this.requestId = requestId;
    }

    public String getClientRequestId() {
        return clientRequestId;
    }

    public void setClientRequestId(String clientRequestId) {
        this.clientRequestId = clientRequestId;
    }

    public String getSourceLang() {
        return sourceLang;
    }

    public void setSourceLang(String sourceLang) {
        this.sourceLang = sourceLang;
    }

    public String getTargetLang() {
        return targetLang;
    }

    public void setTargetLang(String targetLang) {
        this.targetLang = targetLang;
    }

    public String getStyle() {
        return style;
    }

    public void setStyle(String style) {
        this.style = style;
    }

    public Integer getInputChars() {
        return inputChars;
    }

    public void setInputChars(Integer inputChars) {
        this.inputChars = inputChars;
    }

    public Integer getOutputChars() {
        return outputChars;
    }

    public void setOutputChars(Integer outputChars) {
        this.outputChars = outputChars;
    }

    public Long getDurationMs() {
        return durationMs;
    }

    public void setDurationMs(Long durationMs) {
        this.durationMs = durationMs;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }
}
