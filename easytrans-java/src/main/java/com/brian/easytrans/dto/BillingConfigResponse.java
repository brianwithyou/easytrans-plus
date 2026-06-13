package com.brian.easytrans.dto;

import java.util.ArrayList;
import java.util.List;

public class BillingConfigResponse {

    private boolean enabled;
    /** free=基础版免费使用；paid=必须购买基础版后使用 */
    private String mode = "free";
    private List<BillingProductDto> products = new ArrayList<>();

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public String getMode() {
        return mode;
    }

    public void setMode(String mode) {
        this.mode = mode;
    }

    public List<BillingProductDto> getProducts() {
        return products;
    }

    public void setProducts(List<BillingProductDto> products) {
        this.products = products;
    }
}
