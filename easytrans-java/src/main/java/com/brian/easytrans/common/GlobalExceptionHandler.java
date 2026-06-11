package com.brian.easytrans.common;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusiness(BusinessException ex, HttpServletRequest request) {
        String code = ex.getStatus() == HttpStatus.UNAUTHORIZED ? ApiErrorCode.UNAUTHORIZED : ApiErrorCode.BUSINESS_ERROR;
        log.warn("Business error requestId={} code={} message={}", requestId(request), code, ex.getMessage());
        return ResponseEntity.status(ex.getStatus()).body(error(code, ex.getMessage(), request));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(
            MethodArgumentNotValidException ex, HttpServletRequest request) {
        FieldError fieldError = ex.getBindingResult().getFieldError();
        String message = fieldError != null ? fieldError.getDefaultMessage() : "参数校验失败";
        log.warn("Validation error requestId={} message={}", requestId(request), message);
        return ResponseEntity.badRequest().body(error(ApiErrorCode.VALIDATION_ERROR, message, request));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNotFound(NoResourceFoundException ex, HttpServletRequest request) {
        log.warn("Not found requestId={} path={}", requestId(request), ex.getResourcePath());
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(error(ApiErrorCode.NOT_FOUND, "接口不存在", request));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleGeneric(Exception ex, HttpServletRequest request) {
        log.error("Internal error requestId={}", requestId(request), ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(error(ApiErrorCode.INTERNAL_ERROR, "服务器内部错误", request));
    }

    private ApiResponse<Void> error(String code, String message, HttpServletRequest request) {
        return ApiResponse.error(code, message, requestId(request));
    }

    private String requestId(HttpServletRequest request) {
        Object value = request.getAttribute(RequestIdFilter.REQUEST_ID_ATTR);
        return value != null ? value.toString() : null;
    }
}
