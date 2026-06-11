package com.brian.easytrans.common;

public final class DeleteFlagConstants {

    public static final long NOT_DELETED = 0L;

    private DeleteFlagConstants() {}

    public static long deletedMark() {
        return System.currentTimeMillis();
    }
}
