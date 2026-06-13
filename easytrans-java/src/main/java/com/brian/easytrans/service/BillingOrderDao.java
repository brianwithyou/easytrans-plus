package com.brian.easytrans.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.brian.easytrans.entity.BillingOrderEntity;
import com.brian.easytrans.mapper.BillingOrderMapper;
import java.util.Optional;
import org.springframework.stereotype.Component;

@Component
public class BillingOrderDao {

    private final BillingOrderMapper billingOrderMapper;

    public BillingOrderDao(BillingOrderMapper billingOrderMapper) {
        this.billingOrderMapper = billingOrderMapper;
    }

    public boolean existsByLemonOrderIdAndEventName(String lemonOrderId, String eventName) {
        return billingOrderMapper.exists(new LambdaQueryWrapper<BillingOrderEntity>()
                .eq(BillingOrderEntity::getLemonOrderId, lemonOrderId)
                .eq(BillingOrderEntity::getEventName, eventName));
    }

    public Optional<BillingOrderEntity> findPaidOrderByLemonOrderId(String lemonOrderId) {
        return Optional.ofNullable(billingOrderMapper.selectOne(new LambdaQueryWrapper<BillingOrderEntity>()
                .eq(BillingOrderEntity::getLemonOrderId, lemonOrderId)
                .eq(BillingOrderEntity::getEventName, "order_created")));
    }

    public void insert(BillingOrderEntity entity) {
        billingOrderMapper.insert(entity);
    }
}
