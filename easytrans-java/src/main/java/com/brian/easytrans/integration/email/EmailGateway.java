package com.brian.easytrans.integration.email;

public interface EmailGateway {

    void sendVerificationCode(String email, String scene, String code);
}
