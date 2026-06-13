package com.brian.easytrans.common;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
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
    public ResponseEntity<?> handleBusiness(BusinessException ex, HttpServletRequest request) {
        String code = ex.getStatus() == HttpStatus.UNAUTHORIZED ? ApiErrorCode.UNAUTHORIZED : ApiErrorCode.BUSINESS_ERROR;
        log.warn("Business error requestId={} code={} message={}", requestId(request), code, ex.getMessage());
        if (prefersEventStream(request)) {
            return sseError(ex.getStatus(), ex.getMessage());
        }
        return ResponseEntity.status(ex.getStatus()).body(error(code, ex.getMessage(), request));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<?> handleValidation(
            MethodArgumentNotValidException ex, HttpServletRequest request) {
        FieldError fieldError = ex.getBindingResult().getFieldError();
        String message = fieldError != null ? fieldError.getDefaultMessage() : "参数校验失败";
        log.warn("Validation error requestId={} message={}", requestId(request), message);
        if (prefersEventStream(request)) {
            return sseError(HttpStatus.BAD_REQUEST, message);
        }
        return ResponseEntity.badRequest().body(error(ApiErrorCode.VALIDATION_ERROR, message, request));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<?> handleNotFound(NoResourceFoundException ex, HttpServletRequest request) {
        log.warn("Not found requestId={} path={}", requestId(request), ex.getResourcePath());
        if (prefersEventStream(request)) {
            return sseError(HttpStatus.NOT_FOUND, "接口不存在");
        }
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(error(ApiErrorCode.NOT_FOUND, "接口不存在", request));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<?> handleGeneric(Exception ex, HttpServletRequest request) {
        log.error("Internal error requestId={}", requestId(request), ex);
        if (prefersEventStream(request)) {
            return sseError(HttpStatus.INTERNAL_SERVER_ERROR, "服务器内部错误");
        }
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(error(ApiErrorCode.INTERNAL_ERROR, "服务器内部错误", request));
    }

    private boolean prefersEventStream(HttpServletRequest request) {
        String accept = request.getHeader(HttpHeaders.ACCEPT);
        return accept != null && accept.contains(MediaType.TEXT_EVENT_STREAM_VALUE);
    }

    private ResponseEntity<String> sseError(HttpStatus status, String message) {
        String safeMessage = message == null ? "" : message.replace("\"", "\\\"");
        return ResponseEntity.status(status)
                .contentType(MediaType.TEXT_EVENT_STREAM)
                .body("data: {\"error\":\"" + safeMessage + "\"}\n\n");
    }

    private ApiResponse<Void> error(String code, String message, HttpServletRequest request) {
        return ApiResponse.error(code, message, requestId(request));
    }

    private String requestId(HttpServletRequest request) {
        Object value = request.getAttribute(RequestIdFilter.REQUEST_ID_ATTR);
        return value != null ? value.toString() : null;
    }
}
