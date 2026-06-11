package com.brian.easytrans;

import com.brian.easytrans.config.AppProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(AppProperties.class)
public class EasyTransApplication {

    public static void main(String[] args) {
        SpringApplication.run(EasyTransApplication.class, args);
    }
}
