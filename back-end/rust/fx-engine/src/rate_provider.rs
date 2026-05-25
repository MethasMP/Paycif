use async_trait::async_trait;
use rust_decimal::Decimal;
use rust_decimal::prelude::FromStr;
use serde::Deserialize;
use std::collections::HashMap;

/// Exchange rate data from external provider
#[derive(Debug, Clone)]
pub struct ExchangeRate {
    pub from: String,
    pub to: String,
    pub rate: Decimal,
    pub source: String,
}

/// Trait for external rate providers
#[async_trait]
pub trait RateProvider: Send + Sync {
    /// Fetch current rates for base currency
    async fn fetch_rates(&self, base: &str) -> Result<Vec<ExchangeRate>, Box<dyn std::error::Error + Send + Sync>>;
    
    /// Provider name
    fn name(&self) -> &'static str;
}

/// European Central Bank provider (free, XML feed)
pub struct ECBProvider {
    client: reqwest::Client,
}

impl ECBProvider {
    pub fn new() -> Self {
        Self {
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(10))
                .build()
                .expect("Failed to build HTTP client"),
        }
    }
}

#[async_trait]
impl RateProvider for ECBProvider {
    async fn fetch_rates(&self, base: &str) -> Result<Vec<ExchangeRate>, Box<dyn std::error::Error + Send + Sync>> {
        // ECB provides EUR-based rates
        if base != "EUR" {
            return Err("ECB only supports EUR as base currency".into());
        }

        let url = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml";
        let response = self.client.get(url).send().await?;
        let xml = response.text().await?;

        parse_ecb_xml(&xml, base)
    }

    fn name(&self) -> &'static str {
        "ECB"
    }
}

/// Parse ECB XML format
fn parse_ecb_xml(xml: &str, base: &str) -> Result<Vec<ExchangeRate>, Box<dyn std::error::Error + Send + Sync>> {
    use quick_xml::events::Event;
    use quick_xml::Reader;

    let mut rates = Vec::new();
    let mut reader = Reader::from_str(xml);
    reader.trim_text(true);

    let mut buf = Vec::new();
    let _current_currency = String::new();

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Empty(e)) => {
                if e.name().as_ref() == b"Cube" {
                    let mut currency = None;
                    let mut rate = None;

                    for attr in e.attributes() {
                        let attr = attr?;
                        match attr.key.as_ref() {
                            b"currency" => currency = Some(String::from_utf8_lossy(&attr.value).to_string()),
                            b"rate" => rate = Some(String::from_utf8_lossy(&attr.value).to_string()),
                            _ => {}
                        }
                    }

                    if let (Some(curr), Some(rate_str)) = (currency, rate) {
                        if let Ok(rate_dec) = Decimal::from_str(&rate_str) {
                            rates.push(ExchangeRate {
                                from: base.to_string(),
                                to: curr,
                                rate: rate_dec,
                                source: "ECB".to_string(),
                            });
                        }
                    }
                }
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(format!("XML parse error: {}", e).into()),
            _ => {}
        }
        buf.clear();
    }

    Ok(rates)
}

/// Open Exchange Rates provider (requires API key)
pub struct OpenExchangeProvider {
    client: reqwest::Client,
    api_key: String,
}

impl OpenExchangeProvider {
    pub fn new(api_key: String) -> Self {
        Self {
            client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(10))
                .build()
                .expect("Failed to build HTTP client"),
            api_key,
        }
    }
}

#[derive(Deserialize)]
struct OXRResponse {
    rates: HashMap<String, f64>,
}

#[async_trait]
impl RateProvider for OpenExchangeProvider {
    async fn fetch_rates(&self, base: &str) -> Result<Vec<ExchangeRate>, Box<dyn std::error::Error + Send + Sync>> {
        let url = format!(
            "https://openexchangerates.org/api/latest.json?app_id={}&base={}",
            self.api_key, base
        );

        let response = self.client.get(&url).send().await?;
        let data: OXRResponse = response.json().await?;

        let mut rates = Vec::new();
        for (currency, rate) in data.rates {
            if let Ok(rate_dec) = Decimal::try_from(rate) {
                rates.push(ExchangeRate {
                    from: base.to_string(),
                    to: currency,
                    rate: rate_dec,
                    source: "OpenExchangeRates".to_string(),
                });
            }
        }

        Ok(rates)
    }

    fn name(&self) -> &'static str {
        "OpenExchangeRates"
    }
}

/// Mock provider for testing
pub struct MockProvider;

#[async_trait]
impl RateProvider for MockProvider {
    async fn fetch_rates(&self, base: &str) -> Result<Vec<ExchangeRate>, Box<dyn std::error::Error + Send + Sync>> {
        let rates = vec![
            ExchangeRate {
                from: base.to_string(),
                to: "USD".to_string(),
                rate: Decimal::from_str("1.0850")?,
                source: "Mock".to_string(),
            },
            ExchangeRate {
                from: base.to_string(),
                to: "GBP".to_string(),
                rate: Decimal::from_str("0.8500")?,
                source: "Mock".to_string(),
            },
            ExchangeRate {
                from: base.to_string(),
                to: "THB".to_string(),
                rate: Decimal::from_str("38.50")?,
                source: "Mock".to_string(),
            },
        ];
        Ok(rates)
    }

    fn name(&self) -> &'static str {
        "Mock"
    }
}

/// Provider manager that can try multiple providers
pub struct RateProviderManager {
    providers: Vec<Box<dyn RateProvider>>,
}

impl RateProviderManager {
    pub fn new() -> Self {
        Self {
            providers: Vec::new(),
        }
    }

    pub fn add_provider(&mut self, provider: Box<dyn RateProvider>) {
        self.providers.push(provider);
    }

    /// Try each provider in order until one succeeds
    pub async fn fetch_rates(&self, base: &str) -> Result<Vec<ExchangeRate>, Box<dyn std::error::Error + Send + Sync>> {
        let mut last_error = None;

        for provider in &self.providers {
            match provider.fetch_rates(base).await {
                Ok(rates) => {
                    tracing::info!("Successfully fetched rates from {}", provider.name());
                    return Ok(rates);
                }
                Err(e) => {
                    tracing::warn!("Provider {} failed: {}", provider.name(), e);
                    last_error = Some(e);
                }
            }
        }

        Err(last_error.unwrap_or_else(|| "No providers available".into()))
    }
}

impl Default for RateProviderManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ecb_xml_parsing() {
        let xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01">
    <Cube>
        <Cube time="2024-01-15">
            <Cube currency="USD" rate="1.0850"/>
            <Cube currency="GBP" rate="0.8500"/>
            <Cube currency="THB" rate="38.50"/>
        </Cube>
    </Cube>
</gesmes:Envelope>"#;

        let rates = parse_ecb_xml(xml, "EUR").unwrap();
        assert_eq!(rates.len(), 3);
        
        let usd_rate = rates.iter().find(|r| r.to == "USD").unwrap();
        assert_eq!(usd_rate.rate, Decimal::from_str("1.0850").unwrap());
        assert_eq!(usd_rate.from, "EUR");
    }

    #[tokio::test]
    async fn test_mock_provider() {
        let provider = MockProvider;
        let rates = provider.fetch_rates("EUR").await.unwrap();
        
        assert_eq!(rates.len(), 3);
        assert!(rates.iter().any(|r| r.to == "USD"));
        assert!(rates.iter().any(|r| r.to == "THB"));
    }
}
