package com.brian.easytrans.service;

import com.brian.easytrans.config.AppProperties;
import com.brian.easytrans.entity.AppUser;
import com.brian.easytrans.util.AuditFillHelper;
import java.time.LocalDateTime;
import org.springframework.stereotype.Service;

@Service
public class PlanService {

    private final AppProperties appProperties;
    private final AppUserDao appUserDao;

    public PlanService(AppProperties appProperties, AppUserDao appUserDao) {
        this.appProperties = appProperties;
        this.appUserDao = appUserDao;
    }

    public boolean isBillingEnabled() {
        return appProperties.getBilling().isEnabled();
    }

    /** 免费模式：注册即享基础版配额。 */
    public void applyFreePlan(AppUser user) {
        AppProperties.FreePlan freePlan = appProperties.getBilling().getFreePlan();
        user.setPlanName(freePlan.getName());
        user.setDailyQuota(freePlan.getDailyQuota());
        user.setPlanExpiresAt(null);
    }

    /** 收费模式：未购买 / 已到期，不可使用云端翻译。 */
    public void applyUnpaidState(AppUser user) {
        AppProperties.UnpaidPlan unpaidPlan = appProperties.getBilling().getUnpaidPlan();
        user.setPlanName(unpaidPlan.getName());
        user.setDailyQuota(0);
        user.setPlanExpiresAt(null);
    }

    public void syncPlanState(AppUser user) {
        if (!isBillingEnabled()) {
            return;
        }

        if (isPaidPlanActive(user)) {
            return;
        }

        AppProperties.UnpaidPlan unpaidPlan = appProperties.getBilling().getUnpaidPlan();
        if (unpaidPlan.getName().equals(user.getPlanName())
                && user.getDailyQuota() != null
                && user.getDailyQuota() == 0
                && user.getPlanExpiresAt() == null) {
            return;
        }

        applyUnpaidState(user);
        AuditFillHelper.fillOnUpdate(user, user.getId(), "系统");
        appUserDao.update(user);
    }

    public boolean isPaidPlanActive(AppUser user) {
        if (!isBillingEnabled()) {
            return false;
        }
        LocalDateTime expiresAt = user.getPlanExpiresAt();
        return expiresAt != null && expiresAt.isAfter(LocalDateTime.now());
    }

    public boolean hasServiceAccess(AppUser user) {
        if (!isBillingEnabled()) {
            return true;
        }
        return isPaidPlanActive(user);
    }

    public boolean requiresPurchase(AppUser user) {
        return isBillingEnabled() && !isPaidPlanActive(user);
    }

    public void extendPaidPlan(AppUser user, AppProperties.BillingProduct product) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime base = user.getPlanExpiresAt();
        if (base == null || base.isBefore(now)) {
            base = now;
        }

        user.setPlanName(product.getPlanName());
        user.setDailyQuota(product.getDailyQuota());
        user.setPlanExpiresAt(base.plusDays(product.getDurationDays()));
        AuditFillHelper.fillOnUpdate(user, user.getId(), "系统");
        appUserDao.update(user);
    }

    public void revokePaidPlan(AppUser user) {
        applyUnpaidState(user);
        AuditFillHelper.fillOnUpdate(user, user.getId(), "系统");
        appUserDao.update(user);
    }
}
