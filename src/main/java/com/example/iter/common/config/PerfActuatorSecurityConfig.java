package com.example.iter.common.config;

import org.springframework.boot.security.autoconfigure.actuate.web.servlet.EndpointRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

/**
 * 성능 테스트 환경에서 Prometheus가 애플리케이션 지표를 수집할 수 있도록 허용합니다.
 * 운영 프로필에는 적용하지 않으며, Health와 Prometheus 외의 Actuator 엔드포인트는 공개하지 않습니다.
 */
@Configuration(proxyBeanMethods = false)
@Profile("perf")
public class PerfActuatorSecurityConfig {

    @Bean
    @Order(0)
    public SecurityFilterChain perfActuatorSecurityFilterChain(HttpSecurity http) throws Exception {
        http
                .securityMatcher(EndpointRequest.to("health", "prometheus"))
                .authorizeHttpRequests(authorize -> authorize.anyRequest().permitAll())
                .csrf(AbstractHttpConfigurer::disable);

        return http.build();
    }
}
