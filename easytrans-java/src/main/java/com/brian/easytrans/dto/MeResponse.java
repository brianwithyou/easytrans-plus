package com.brian.easytrans.dto;

public class MeResponse {

    private String email;
    private String planName;
    private Integer dailyQuota;
    private Integer dailyUsed;
    private java.time.LocalDateTime planExpiresAt;
    private Boolean paidPlanActive;
    private Boolean requiresPurchase;

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPlanName() {
        return planName;
    }

    public void setPlanName(String planName) {
        this.planName = planName;
    }

    public Integer getDailyQuota() {
        return dailyQuota;
    }

    public void setDailyQuota(Integer dailyQuota) {
        this.dailyQuota = dailyQuota;
    }

    public Integer getDailyUsed() {
        return dailyUsed;
    }

    public void setDailyUsed(Integer dailyUsed) {
        this.dailyUsed = dailyUsed;
    }

    public java.time.LocalDateTime getPlanExpiresAt() {
        return planExpiresAt;
    }

    public void setPlanExpiresAt(java.time.LocalDateTime planExpiresAt) {
        this.planExpiresAt = planExpiresAt;
    }

    public Boolean getPaidPlanActive() {
        return paidPlanActive;
    }

    public void setPaidPlanActive(Boolean paidPlanActive) {
        this.paidPlanActive = paidPlanActive;
    }

    public Boolean getRequiresPurchase() {
        return requiresPurchase;
    }

    public void setRequiresPurchase(Boolean requiresPurchase) {
        this.requiresPurchase = requiresPurchase;
    }
}
