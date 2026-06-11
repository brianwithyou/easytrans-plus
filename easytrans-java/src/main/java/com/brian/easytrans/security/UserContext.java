package com.brian.easytrans.security;

public final class UserContext {

    private static final ThreadLocal<String> USER_ID = new ThreadLocal<>();

    private UserContext() {}

    public static void setUserId(String userId) {
        USER_ID.set(userId);
    }

    public static String getUserId() {
        return USER_ID.get();
    }

    public static void clear() {
        USER_ID.remove();
    }
}
