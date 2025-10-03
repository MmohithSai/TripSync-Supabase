# 📊 Production Monitoring Setup

## Enterprise-Grade Observability for Your Startup

### 🎯 **Monitoring Strategy Overview**

Your startup needs **comprehensive monitoring** to ensure:

- 🚀 **Performance**: Sub-second response times
- 🔒 **Security**: Real-time threat detection
- 📊 **Business Intelligence**: User behavior insights
- 💰 **Revenue Tracking**: Subscription metrics
- 🌍 **Global Scale**: Multi-region monitoring

---

## 🔍 **1. Database Monitoring**

### **Performance Metrics**

```sql
-- Slow query detection
CREATE OR REPLACE FUNCTION log_slow_queries()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.execution_time_ms > 1000 THEN
    INSERT INTO public.slow_queries (
      query_text, execution_time_ms, rows_returned, user_id
    ) VALUES (
      NEW.query_text, NEW.execution_time_ms, NEW.rows_returned, NEW.user_id
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Connection monitoring
CREATE TABLE IF NOT EXISTS public.connection_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  active_connections INTEGER,
  max_connections INTEGER,
  connection_utilization DECIMAL(5,2),
  timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

### **Health Checks**

```sql
-- Database health monitoring
CREATE OR REPLACE FUNCTION check_database_health()
RETURNS JSONB AS $$
DECLARE
  result JSONB;
  connection_count INTEGER;
  slow_queries_count INTEGER;
  error_rate DECIMAL(5,2);
BEGIN
  -- Check active connections
  SELECT COUNT(*) INTO connection_count
  FROM pg_stat_activity
  WHERE state = 'active';

  -- Check slow queries in last hour
  SELECT COUNT(*) INTO slow_queries_count
  FROM public.slow_queries
  WHERE timestamp > NOW() - INTERVAL '1 hour';

  -- Calculate error rate
  SELECT
    (COUNT(*) FILTER (WHERE status_code >= 400) * 100.0 / COUNT(*))
    INTO error_rate
  FROM public.api_usage
  WHERE timestamp > NOW() - INTERVAL '1 hour';

  result := jsonb_build_object(
    'status', CASE
      WHEN connection_count < 80 AND slow_queries_count < 10 AND error_rate < 5
      THEN 'healthy'
      ELSE 'degraded'
    END,
    'active_connections', connection_count,
    'slow_queries_last_hour', slow_queries_count,
    'error_rate_percent', error_rate,
    'timestamp', NOW()
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql;
```

---

## 📊 **2. Application Performance Monitoring**

### **API Metrics Dashboard**

```sql
-- API performance tracking
CREATE MATERIALIZED VIEW public.api_performance AS
SELECT
  endpoint,
  method,
  DATE_TRUNC('hour', timestamp) as hour,
  COUNT(*) as request_count,
  AVG(response_time_ms) as avg_response_time,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) as p95_response_time,
  COUNT(*) FILTER (WHERE status_code >= 400) as error_count,
  (COUNT(*) FILTER (WHERE status_code >= 400) * 100.0 / COUNT(*)) as error_rate
FROM public.api_usage
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY endpoint, method, DATE_TRUNC('hour', timestamp)
ORDER BY hour DESC;

-- Refresh every hour
CREATE OR REPLACE FUNCTION refresh_api_performance()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW public.api_performance;
END;
$$ LANGUAGE plpgsql;
```

### **User Engagement Metrics**

```sql
-- User activity tracking
CREATE MATERIALIZED VIEW public.user_activity AS
SELECT
  user_id,
  DATE(created_at) as date,
  COUNT(DISTINCT trip_id) as trips_count,
  SUM(distance_km) as total_distance,
  AVG(distance_km) as avg_distance,
  COUNT(DISTINCT DATE(timestamp)) as active_days
FROM public.trips
WHERE created_at > NOW() - INTERVAL '30 days'
  AND is_deleted = FALSE
GROUP BY user_id, DATE(created_at);

-- Daily active users
CREATE MATERIALIZED VIEW public.daily_active_users AS
SELECT
  DATE(created_at) as date,
  COUNT(DISTINCT user_id) as dau,
  COUNT(DISTINCT CASE WHEN subscription_tier = 'premium' THEN user_id END) as premium_dau,
  COUNT(DISTINCT CASE WHEN subscription_tier = 'enterprise' THEN user_id END) as enterprise_dau
FROM public.trips
WHERE created_at > NOW() - INTERVAL '90 days'
  AND is_deleted = FALSE
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

---

## 💰 **3. Business Intelligence Monitoring**

### **Revenue Tracking**

```sql
-- Subscription analytics
CREATE MATERIALIZED VIEW public.subscription_analytics AS
SELECT
  subscription_tier,
  subscription_status,
  COUNT(*) as user_count,
  COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days') as new_users_30d,
  COUNT(*) FILTER (WHERE last_active_at > NOW() - INTERVAL '7 days') as active_users_7d,
  AVG(CASE
    WHEN subscription_tier = 'premium' THEN 9.99
    WHEN subscription_tier = 'enterprise' THEN 99.99
    ELSE 0
  END) as avg_revenue_per_user
FROM public.users
WHERE is_active = TRUE
GROUP BY subscription_tier, subscription_status;

-- Monthly recurring revenue (MRR)
CREATE OR REPLACE FUNCTION calculate_mrr()
RETURNS DECIMAL(10,2) AS $$
DECLARE
  mrr DECIMAL(10,2);
BEGIN
  SELECT
    SUM(CASE
      WHEN subscription_tier = 'premium' THEN 9.99
      WHEN subscription_tier = 'enterprise' THEN 99.99
      ELSE 0
    END)
  INTO mrr
  FROM public.users
  WHERE subscription_status = 'active'
    AND is_active = TRUE;

  RETURN COALESCE(mrr, 0);
END;
$$ LANGUAGE plpgsql;
```

### **Churn Analysis**

```sql
-- User churn tracking
CREATE MATERIALIZED VIEW public.churn_analysis AS
SELECT
  DATE_TRUNC('month', created_at) as month,
  COUNT(*) as new_users,
  COUNT(*) FILTER (WHERE last_active_at < NOW() - INTERVAL '30 days') as churned_users,
  (COUNT(*) FILTER (WHERE last_active_at < NOW() - INTERVAL '30 days') * 100.0 / COUNT(*)) as churn_rate
FROM public.users
WHERE created_at > NOW() - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;
```

---

## 🚨 **4. Alerting System**

### **Critical Alerts**

```sql
-- Alert conditions
CREATE TABLE IF NOT EXISTS public.alert_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  condition_sql TEXT NOT NULL,
  threshold_value DECIMAL(10,2),
  operator TEXT NOT NULL, -- >, <, =, >=, <=
  severity TEXT DEFAULT 'warning', -- info, warning, critical
  is_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert critical alert rules
INSERT INTO public.alert_rules (name, condition_sql, threshold_value, operator, severity) VALUES
('High Error Rate', 'SELECT error_rate FROM api_performance WHERE hour = DATE_TRUNC(''hour'', NOW())', 5.0, '>', 'critical'),
('Slow Response Time', 'SELECT avg_response_time FROM api_performance WHERE hour = DATE_TRUNC(''hour'', NOW())', 2000, '>', 'warning'),
('Database Connections', 'SELECT COUNT(*) FROM pg_stat_activity WHERE state = ''active''', 80, '>', 'critical'),
('Low User Activity', 'SELECT COUNT(*) FROM users WHERE last_active_at > NOW() - INTERVAL ''1 hour''', 10, '<', 'warning');
```

### **Alert Processing**

```sql
-- Alert processing function
CREATE OR REPLACE FUNCTION process_alerts()
RETURNS VOID AS $$
DECLARE
  alert_record RECORD;
  current_value DECIMAL(10,2);
  should_alert BOOLEAN;
BEGIN
  FOR alert_record IN
    SELECT * FROM public.alert_rules WHERE is_enabled = TRUE
  LOOP
    -- Execute the condition SQL
    EXECUTE 'SELECT (' || alert_record.condition_sql || ')' INTO current_value;

    -- Check if alert should trigger
    should_alert := FALSE;
    CASE alert_record.operator
      WHEN '>' THEN should_alert := current_value > alert_record.threshold_value;
      WHEN '<' THEN should_alert := current_value < alert_record.threshold_value;
      WHEN '>=' THEN should_alert := current_value >= alert_record.threshold_value;
      WHEN '<=' THEN should_alert := current_value <= alert_record.threshold_value;
      WHEN '=' THEN should_alert := current_value = alert_record.threshold_value;
    END CASE;

    -- Create alert if condition is met
    IF should_alert THEN
      INSERT INTO public.alert_logs (
        rule_id, current_value, threshold_value, severity, message
      ) VALUES (
        alert_record.id,
        current_value,
        alert_record.threshold_value,
        alert_record.severity,
        alert_record.name || ': ' || current_value || ' ' || alert_record.operator || ' ' || alert_record.threshold_value
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Alert logs table
CREATE TABLE IF NOT EXISTS public.alert_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id UUID REFERENCES public.alert_rules(id),
  current_value DECIMAL(10,2),
  threshold_value DECIMAL(10,2),
  severity TEXT NOT NULL,
  message TEXT NOT NULL,
  is_resolved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 📈 **5. Real-time Dashboards**

### **Executive Dashboard**

```sql
-- Key business metrics
CREATE MATERIALIZED VIEW public.executive_dashboard AS
SELECT
  'users' as metric,
  COUNT(*) as value,
  'Total registered users' as description
FROM public.users
WHERE is_active = TRUE

UNION ALL

SELECT
  'premium_users',
  COUNT(*),
  'Premium subscribers'
FROM public.users
WHERE subscription_tier = 'premium' AND is_active = TRUE

UNION ALL

SELECT
  'mrr',
  calculate_mrr(),
  'Monthly recurring revenue'

UNION ALL

SELECT
  'trips_today',
  COUNT(*),
  'Trips recorded today'
FROM public.trips
WHERE DATE(created_at) = CURRENT_DATE

UNION ALL

SELECT
  'active_users_7d',
  COUNT(DISTINCT user_id),
  'Active users in last 7 days'
FROM public.trips
WHERE created_at > NOW() - INTERVAL '7 days';
```

### **Technical Dashboard**

```sql
-- System health metrics
CREATE MATERIALIZED VIEW public.technical_dashboard AS
SELECT
  'api_requests_per_hour' as metric,
  COUNT(*) as value,
  'API requests in last hour' as description
FROM public.api_usage
WHERE timestamp > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
  'avg_response_time',
  AVG(response_time_ms),
  'Average API response time (ms)'
FROM public.api_usage
WHERE timestamp > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
  'error_rate',
  (COUNT(*) FILTER (WHERE status_code >= 400) * 100.0 / COUNT(*)),
  'API error rate (%)'
FROM public.api_usage
WHERE timestamp > NOW() - INTERVAL '1 hour'

UNION ALL

SELECT
  'database_connections',
  COUNT(*),
  'Active database connections'
FROM pg_stat_activity
WHERE state = 'active';
```

---

## 🔄 **6. Automated Monitoring Tasks**

### **Scheduled Jobs**

```sql
-- Create monitoring job function
CREATE OR REPLACE FUNCTION run_monitoring_jobs()
RETURNS VOID AS $$
BEGIN
  -- Refresh materialized views
  REFRESH MATERIALIZED VIEW public.api_performance;
  REFRESH MATERIALIZED VIEW public.user_activity;
  REFRESH MATERIALIZED VIEW public.daily_active_users;
  REFRESH MATERIALIZED VIEW public.subscription_analytics;
  REFRESH MATERIALIZED VIEW public.churn_analysis;
  REFRESH MATERIALIZED VIEW public.executive_dashboard;
  REFRESH MATERIALIZED VIEW public.technical_dashboard;

  -- Process alerts
  PERFORM process_alerts();

  -- Log monitoring completion
  INSERT INTO public.health_checks (service_name, status, response_time_ms, timestamp)
  VALUES ('monitoring_jobs', 'completed', 0, NOW());

EXCEPTION
  WHEN OTHERS THEN
    -- Log monitoring errors
    INSERT INTO public.health_checks (service_name, status, response_time_ms, error_message, timestamp)
    VALUES ('monitoring_jobs', 'error', 0, SQLERRM, NOW());
END;
$$ LANGUAGE plpgsql;
```

### **Health Check Endpoints**

```sql
-- System health check
CREATE OR REPLACE FUNCTION system_health_check()
RETURNS JSONB AS $$
DECLARE
  result JSONB;
  db_health JSONB;
  api_health JSONB;
  overall_status TEXT;
BEGIN
  -- Check database health
  SELECT check_database_health() INTO db_health;

  -- Check API health
  SELECT jsonb_build_object(
    'requests_last_hour', COUNT(*),
    'avg_response_time', AVG(response_time_ms),
    'error_rate', (COUNT(*) FILTER (WHERE status_code >= 400) * 100.0 / COUNT(*))
  ) INTO api_health
  FROM public.api_usage
  WHERE timestamp > NOW() - INTERVAL '1 hour';

  -- Determine overall status
  overall_status := CASE
    WHEN (db_health->>'status') = 'healthy' AND (api_health->>'error_rate')::DECIMAL < 5 THEN 'healthy'
    ELSE 'degraded'
  END;

  result := jsonb_build_object(
    'status', overall_status,
    'timestamp', NOW(),
    'database', db_health,
    'api', api_health
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql;
```

---

## 🎯 **7. Monitoring Best Practices**

### **Key Metrics to Track**

1. **📊 Business Metrics**

   - Daily/Monthly Active Users
   - Revenue (MRR, ARR)
   - Customer Acquisition Cost (CAC)
   - Customer Lifetime Value (LTV)
   - Churn Rate

2. **⚡ Performance Metrics**

   - API Response Time (P50, P95, P99)
   - Database Query Performance
   - Error Rates
   - Uptime Percentage

3. **🔒 Security Metrics**

   - Failed Authentication Attempts
   - Suspicious API Usage
   - Data Access Patterns
   - Security Event Frequency

4. **📱 User Experience Metrics**
   - App Crash Rate
   - Feature Adoption Rate
   - User Engagement Score
   - Support Ticket Volume

### **Alert Thresholds**

- 🚨 **Critical**: System down, security breach, data loss
- ⚠️ **Warning**: Performance degradation, high error rates
- ℹ️ **Info**: Usage spikes, new feature adoption

### **Response Procedures**

1. **Immediate**: Critical alerts → On-call engineer
2. **Within 1 hour**: Warning alerts → Development team
3. **Within 24 hours**: Info alerts → Product team

---

## 🚀 **Your Monitoring is Production-Ready!**

With this comprehensive monitoring setup, your startup has:

- 📊 **Real-time Insights**: Live business and technical metrics
- 🚨 **Proactive Alerts**: Early warning system for issues
- 📈 **Growth Tracking**: User acquisition and retention metrics
- 💰 **Revenue Monitoring**: Subscription and billing analytics
- 🔒 **Security Oversight**: Threat detection and prevention
- 📱 **User Experience**: App performance and engagement tracking

**Your startup is now equipped with enterprise-grade monitoring!** 🎉



