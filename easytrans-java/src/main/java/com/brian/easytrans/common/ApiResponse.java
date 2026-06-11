package com.brian.easytrans.common;

public class ApiResponse<T> {

    private String code;
    private String message;
    private T data;
    private String requestId;

    public ApiResponse() {}

    public ApiResponse(String code, String message, T data, String requestId) {
        this.code = code;
        this.message = message;
        this.data = data;
        this.requestId = requestId;
    }

    public static <T> ApiResponse<T> success(T data, String requestId) {
        return new ApiResponse<>(ApiErrorCode.SUCCESS, "ok", data, requestId);
    }

    public static <T> ApiResponse<T> error(String code, String message, String requestId) {
        return new ApiResponse<>(code, message, null, requestId);
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public T getData() {
        return data;
    }

    public void setData(T data) {
        this.data = data;
    }

    public String getRequestId() {
        return requestId;
    }

    public void setRequestId(String requestId) {
        this.requestId = requestId;
    }
}
