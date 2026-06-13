package com.brian.easytrans.service;

import com.brian.easytrans.entity.TranslationEventEntity;
import com.brian.easytrans.mapper.TranslationEventMapper;
import org.springframework.stereotype.Component;

@Component
public class TranslationEventDao {

    private final TranslationEventMapper translationEventMapper;

    public TranslationEventDao(TranslationEventMapper translationEventMapper) {
        this.translationEventMapper = translationEventMapper;
    }

    public void insert(TranslationEventEntity entity) {
        translationEventMapper.insert(entity);
    }
}
