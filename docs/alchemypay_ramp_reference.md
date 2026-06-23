# Alchemy Pay RAMP Integration Reference

This document is a compiled reference of the Alchemy Pay RAMP integration options, signature calculations, parameter customisation, APIs, and Webhook guides.

---

## Table of Contents
1. [Integration Options](#1-integration-options)
2. [Testing Notes](#2-testing-notes)
3. [Page Integration](#3-page-integration)
4. [Ramp Signature Description](#4-ramp-signature-description)
5. [On Ramp Custom Parameters](#5-on-ramp-custom-parameters)
6. [Off Ramp Custom Parameters](#6-off-ramp-custom-parameters)
7. [API Integration](#7-api-integration)
8. [Get Token](#8-get-token)
9. [API Sign](#9-api-sign)
10. [Webhook](#10-webhook)
11. [Webhook Signature](#11-webhook-signature)
12. [List of Fiat Currencies, Cryptocurrencies, and KYC](#12-list-of-fiat-currencies-cryptocurrencies-and-kyc)

---

## 1. Integration Options
**Source:** [https://alchemypay.readme.io/docs/integration-options](https://alchemypay.readme.io/docs/integration-options)

### Introduction
To provide you with a seamless user journey and experience, AlchemyPay integration can flexibly adapt to any type of application. AlchemyPay supports three integration methods, and you can integrate according to your own needs:

1. **Page Integration**
2. **API Integration**
3. **Native API Integration**

### Page Integration
This is the fastest and simplest way to integrate with AlchemyPay. It can be directly embedded into your website or directly redirected to our page using buttons. The users complete all steps on the ACH page.
*   [Page Integration Documentation](/docs/page-integration-2)

### Standard API Integration
The API method allows you to create an order directly through the backend API, and AlchemyPay will directly return the payment link. The user finish payment process on our pages.
*   [Standard API Integration Documentation](/docs/api-integration)

### Native API Integration
This api allow partners to design all the pages and integrate Alchemy Pay via interface. This integration require [KYC sharing](/docs/ramp-shared-kyc).
*\*Assessment is required before access.*
*   [Native API Integration Documentation](/docs/native-api-integration)

> [!WARNING]
> 🚧 Before testing, please check Testing Notes

### RAMP Integration Guide
You can integrate RAMP products by following the steps below:
1. **Understand ONRAMP and OFFRAMP:** Learn the basics of [RAMP](/docs/alchemypay-on-ramp#/) products.
2. **Choose an integration mode and apply whitelist:**
    *   Review the [Integration Options](/docs/integration-options#/)
    *   Review the testing notes and send [whitelist email](/docs/testing-notes#whitelist)
    *   Review the [payment method supported](https://alchemypay.notion.site/Payment-Methods-Coverages-Other-Details-Table-fb3b4f5c68c04b9b8619c48aad31277d)
3. **Estimate order amounts before generating order:**
    *   **Step 1:** Call [Crypto Query](/docs/crypto-query#/) to check supported cryptocurrencies and limits.
    *   **Step 2:** Call [Fiat Query](/docs/fiat-query#/) to check supported payment methods and limits.
    *   **Step 3:** Call [Price Query](/docs/price-query#/) if you need an order estimate.
4. **Generate a checkout URL in the sandbox:**
    *   In the sandbox environment, both payments and crypto transfers are real.
    *   Updating Order Status via Webhooks or Order Query API.
        *   [Webhook](/docs/webhook#/): Webhook url can be passed via create order url parameter `callbackUrl`.
        *   [Order Query API](/docs/query-order-2#/): Update order status by order query.
    *   Other parts should be verified in the production environment: [Page mode documentation](/docs/on-ramp-custom-parameters#/)

Contact us for a production account and go live.

---

## 2. Testing Notes
**Source:** [https://alchemypay.readme.io/docs/testing-notes](https://alchemypay.readme.io/docs/testing-notes)

### Testing Flow
1. Pass KYB
2. Apply Whitelist
3. Get Sandbox Account by contacting the technical support team
4. Closed-loop testing in a sandbox environment
5. Apply Production Account and go live

### Before Testing
*   **Real payment testing:** Sandbox environment is real transaction.
*   **No KYC payment limit:** No KYC verification is required for amounts below $20. It's recommended to test with a small amount.
*   **Test recommendation:** Start with crypto: `USDT`/`USDC`, network: `BSC`/`TRX`, fiat: `USD`. For testing various cryptos, use production environment. Recommended using credit card payment.
*   **Merchant dashboard:** No merchant dashboard in sandbox environment is provided. Merchant can get more information from [ramp merchant dashboard](/docs/ramp-merchant-backend). After receiving the production account, merchants can log in to the merchant dashboard.
*   **Test Card:** We recommend selecting card payment in the sandbox environment to complete the closed-loop testing. Test cards are available upon request; you can reach out to our technical support team for them.

### Whitelist
Please send us an email including the testing account (email) and testing card for whitelist to avoid test payment failures due to risk control reasons.
Please send this form to the email addresses: [dispute@alchemypay.org](mailto:dispute@alchemypay.org), [koalahyl@alchemypay.org](mailto:koalahyl@alchemypay.org)

#### Whitelist Apply Form
| Item | Details |
| --- | --- |
| **Business Name** | [Please fill in] |
| **Merchant ID** | APPID |
| **Merchant Website** | [Please fill in] |
| **Services provided by merchants** | Please describe the business scenario |
| **Have you passed our company's KYB?** | |
| **Integrated product** | Ramp |
| **Testing Period** | Start and end date |
| **Testing environment** | Sandbox environment / Product environment / Sandbox & Product environment |
| **Testing email** | Please fill in all the test email addresses |
| **Will multiple accounts use the same wallet address?** | If so, please provide the wallet address used by your company for testing purposes |

---

## 3. Page Integration
**Source:** [https://alchemypay.readme.io/docs/page-integration-2](https://alchemypay.readme.io/docs/page-integration-2)

### Introduction
This is the fastest and easiest way to integrate with AlchemyPay. Generate a URL with `appId`, and redirect the user to on-ramp for purchasing tokens.

**Integration Methods:**
*   **Web:** Popup, embedded on webpage, iframe
*   **App:** H5 embedded page

*The URL that the merchant redirects to must include the signature string. Check details below.*

> [!NOTE]
> ### Tips
> To improve the user experience, it is recommended to open AlchemyPay on a new tab with the `redirectURL` parameter, so that your users can redirect back to your website after completing the payment.

### Domains
*   **Test Environment:** `https://ramptest.alchemypay.org`
*   **Prod Environment:** `https://ramp.alchemypay.org`

### Redirection
When redirecting, you need to include parameters such as the `appId` assigned to you by AlchemyPay. For parameter details, [Click Here](/docs/on-ramp-custom-parameters).

```text
<a href="https://ramptest.alchemypay.org/?appId=[YOUR_TEST_APPID]&[CUSTOM_PARAMETERS]>">
Buy/Sell Crypto with AlchemyPay</a>
```

### Iframe
You can add AlchemyPay directly to the pages of your website or application using the sample code below.
We recommend testing to ensure the default Iframe height and width in the code below work well for your page, and adjust them if needed.

```text
<iframe height="625" title="AlchemyPay On/Off Ramp Widget"
src="https://ramptest.alchemypay.org/?appId=[YOUR_TEST_APPID]&[CUSTOM_PARAMETERS]" 
frameborder="no" allowtransparency="true" allowfullscreen="" 
style="display: block; width: 100%; max-height: 625px; max-width: 500px;">
</iframe>
```

To ensure users can successfully perform KYC within the iframe, the following configuration is required for iOS. Otherwise, the camera video stream will only start when the user clicks the "play" button, causing the logic to time out because it cannot obtain the image.
1. `WKWebViewConfiguration` must be set with `allowsInlineMediaPlayback=YES`
2. `mediaTypesRequiringUserActionForPlayback` must be set to `None`.

### User Flow
The page for users to confirm the purchase amount cannot be **skipped**.

---

## 4. Ramp Signature Description
**Source:** [https://alchemypay.readme.io/docs/ramp-signature-description](https://alchemypay.readme.io/docs/ramp-signature-description)

Applicable to the On Ramp/Off Ramp interface.

### Signature Parameters
| Element | Description | Remarks |
| --- | --- | --- |
| timestamp | Thirteen-digit timestamp | 1538054050234 |
| httpMethod | Request Method GET/POST | Request method must be in uppercase. |
| requestPath | Request Path | On-ramp: `/index/rampPageBuy`<br>Off-ramp: `/index/rampPageSell` |
| bodyString | bodyString | GET: empty<br>POST: body parameters |

### Step 1: Generate An Encrypted String
The signature string is fixed as follows: `timestamp` + `httpMethod` + `requestPath` + `bodyString`.
For the parameters in `requestPath`, sort them in dictionary order and remove any empty values.
Finally, encrypt using HMAC SHA256 with the `SecretKey` and encode it using Base64 to obtain the sign.

#### On Ramp Example:
*   **Request link:** `https://ramptest.alchemypay.org?appId=f83Is2y7L425rxl8&crypto=USDT&network=ETH&showTable=buy&fiat=USD&fiatAmount=30&timestamp=1538054050234&sign=JY9JcOwBosncT19Nn9DIfTH%2BvfSt6xL%2BI%2BRVCl9YGgE%3D`
*   **httpMethod:** `GET`
*   **requestPath:** `/index/rampPageBuy`
*   **bodyString:** *(empty)*
*   **Signature String:** `1538054050234GET/index/rampPageBuy?appId=f83Is2y7L425rxl8&crypto=USDT&fiat=USD&fiatAmount=30&network=ETH&showTable=buy&timestamp=1538054050234`

#### Off Ramp Example:
*   **Request link:** `https://ramptest.alchemypay.org?appId=f83Is2y7L425rxl8&crypto=USDT&network=ETH&showTable=sell&fiat=USD&cryptoAmount=30&timestamp=1538054050234&sign=615hNootKL4aScndVHxqRnuZzoLDCJU%2FBzhHj913qlk%3D`
*   **timestamp:** `1538054050234`
*   **httpMethod:** `GET`
*   **requestPath:** `/index/rampPageSell`
*   **bodyString:** *(empty)*
*   **Signature String:** `1538054050234GET/index/rampPageSell?appId=f83Is2y7L425rxl8&crypto=USDT&cryptoAmount=30&fiat=USD&network=ETH&showTable=sell&timestamp=1538054050234`

### Step 2: Generate Your Signature
Use the encrypted string and secret as parameters to generate a signature as follows:

```java
package v4.onramp;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;

// Example for on-ramp page signature generation
public class V4OnrampPage {

    public static void main(String[] args) throws Exception {
        // Generate current timestamp in milliseconds
        String timestamp = String.valueOf(System.currentTimeMillis());
        String httpMethod = "GET";
        String requestPath = "/index/rampPageBuy"; // onramp: /index/rampPageBuy, offramp: /index/rampPageSell
        String secretKey = "*****"; // replace with your secretKey
        String appId = "*****"; // replace with your appId
        
        // Request parameters
        Map<String, String> paramsToSign = new TreeMap<>();
        paramsToSign.put("crypto", "USDT");
        paramsToSign.put("fiatAmount", "200");
        paramsToSign.put("fiat", "USD");
        paramsToSign.put("merchantOrderNo", "1731231234567890123455"); // Cannot be repeated
        paramsToSign.put("network", "BSC");
        paramsToSign.put("callbackUrl", "https://google.com");
        paramsToSign.put("redirectUrl", "https://google.com");
        paramsToSign.put("timestamp", timestamp);
        paramsToSign.put("appId", appId);

        // Create the string to sign
        String rawDataToSign = getStringToSign(paramsToSign);
        requestPath += "?" + rawDataToSign;

        // Generate the signature
        String signature = generateSignature(timestamp, httpMethod, requestPath, secretKey);
        String rawData = getStringToSign(paramsToSign);

        // Print the results
        System.out.println("On Ramp Signature: " + signature);
        System.out.println("final link: " + "https://ramptest.alchemypay.org?" + rawData + "&sign=" + signature);
    }

    private static String generateSignature(String timestamp, String httpMethod, String requestPath, String secretKey) throws Exception {
        String signatureString = timestamp + httpMethod + requestPath;
        System.out.println("sign-content: " + signatureString);

        Mac sha256Hmac = Mac.getInstance("HmacSHA256");
        SecretKeySpec secretKeySpec = new SecretKeySpec(secretKey.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        sha256Hmac.init(secretKeySpec);

        byte[] hash = sha256Hmac.doFinal(signatureString.getBytes(StandardCharsets.UTF_8));
        String signature = java.util.Base64.getEncoder().encodeToString(hash);
        System.out.println("sign-String: " + signature);
        return URLEncoder.encode(signature, StandardCharsets.UTF_8.toString());
    }

    private static String getStringToSign(Map<String, String> params) {
        return params.entrySet().stream()
                .filter(entry -> entry.getValue() != null && !entry.getValue().isEmpty())
                .map(entry -> entry.getKey() + "=" + entry.getValue())
                .collect(Collectors.joining("&"));
    }
}
```

---

## 5. On Ramp Custom Parameters
**Source:** [https://alchemypay.readme.io/docs/on-ramp-custom-parameters](https://alchemypay.readme.io/docs/on-ramp-custom-parameters)

### Introduction
*   **Simplify user flow:** You can pass parameters to replace user input.
*   Please verify the user's email address before using the `email` parameter.
*   [Skip login page](/docs/login-free-instructions) by using the `token` parameter.
*   All parameters sent need to be signed.

**Example link:** `https://ramptest.alchemypay.org?appId=f83Is2y7L425rxl8&crypto=USDT&network=ETH&showTable=buy&fiat=USD&fiatAmount=30&timestamp=1538054050234&sign=JY9JcOwBosncT19Nn9DIfTH%2BvfSt6xL%2BI%2BRVCl9YGgE%3D`

### Request Parameters
| Element | Mandatory | Data Type | Remarks |
| --- | --- | --- | --- |
| appId | Y | string | Unique identifier assigned by Alchemy Pay. You can find it in the merchant backend |
| timestamp | Y | string | Thirteen-digit timestamp |
| merchantOrderNo | Y | string | Merchant Order Number (Unique), max 48 characters. This parameter will carry in the webhook, allowing to track order. |
| sign | Y | string | Signature. All parameters sent need to be signed. [Sign rules](/docs/ramp-signature-description) |
| fiat | N | string | Fiat Currency (Uppercase), example: `USD`. The fiat currency to be paid by the user, [query supported fiat currency](/docs/fiat-query). **If passed, the user will not be able to change the fiat currency** |
| fiatAmount | N | string | The fiat currency amount that the user needs to pay. If passed, the user will not be able to modify the order amount. When passing `fiatAmount`, it is necessary to simultaneously include the `fiat` parameter; otherwise, it will be meaningless.* |
| crypto | N | string | The cryptocurrency that the user wants to purchase. You can check the supported cryptocurrencies by Alchemy Pay [Click Here](/docs/crypto-currency-coverage). If passed, the user will not be able to change the cryptocurrencies. `crypto` and `network` must match; if they don't match, the parameter will not take effect.** |
| network | N | string | The cryptocurrency network that the user is allowed to use. It is recommended to pass `network` and `crypto` together to accurately limit the cryptocurrency the user can purchase. You can check the supported networks by Alchemy Pay [Click Here](/docs/network-code). If passed, the user will not be able to change the network. `crypto` and `network` must match; if they don't match, the parameter will not take effect.* |
| address | N | string | User’s wallet address. **If passed, the user will not be able to change the wallet address. The `address` must match the `network`; otherwise, the passed parameter will not take effect.** |
| memo | N | string | Note: some networks require the memo field to be uploaded. Please refer [Click Here](/docs/memo-list) |
| email | N | string | The user's email. If you pass this parameter, we will automatically pre-fill the email. However, the user still needs to enter an email verification code to verify the email. |
| token | N | string | If you have already verified the user's email and want to skip the email verification process in AlchemyPay's experience, you can pass this parameter. Refer to this link for the token generation rules. [Click Here](/docs/login-free-instructions). If the token parameter is uploaded, the email parameter does not need to be uploaded. |
| language | N | string | The language of the ramp page opened by the user. Spanish: `es`, Traditional Chinese: `zh-HK`, English: `en-US`, Vietnamese: `vi`, Indonesian: `id`. eg: `language=en-US` |
| showTable | N | string | If you want to display only the on-ramp options on the ramp page, you can pass this parameter. Use `showTable=buy`. |
| redirectUrl | N | string | The URL of the web page where the user will be redirected after a successful/failed purchase. **URL encoding is required when concatenating to the request URL.** |
| callbackUrl | N | string | After a successful/failed purchase, Alchemy Pay will notify you of the payment result at this address. Refer to this link for the specific notification content. [Click Here](/docs/webhook). **URL encoding is required when concatenating to the request URL.** |
| merchantName | N | string | When merchants pass this custom name, the merchant name displayed on the order completion page will be shown according to this parameter. |
| displayAddress | N | string | Fixed: `true`. If the `address` parameter is uploaded along with this parameter, it will redirect to the "Confirm wallet address page". |

### Implementing Google Pay on Android
Currently Google Pay cannot be used as a webview within Android apps. This is because pop-up blockers are built into the webviews, preventing Google Pay to be displayed. As a result, in order to allow your customers to purchase crypto using Google Pay, you will need to redirect the customer to the browser.
*   Refer to this: [https://alchemypay.readme.io/v4.0.2/docs/google-pay-android-adaptation-solution](/docs/google-pay-android-adaptation-solution)
*   Official documentation for Google Pay: [https://developers.google.com/pay/api/web/support/faq](https://developers.google.com/pay/api/web/support/faq)

---

## 6. Off Ramp Custom Parameters
**Source:** [https://alchemypay.readme.io/docs/off-ramp-custom-parameters](https://alchemypay.readme.io/docs/off-ramp-custom-parameters)

### Introduction
*   By using page mode, you can pass parameters to replace user input and simplify the user flow.
*   If you cannot confirm the user's email, please do not use the `email` parameter. If you have not verified the user's email, please do not use the `token` parameter.
*   The link will take effect only after the mandatory parameters are sent.
*   All parameters sent need to be signed.
*   Order timeout in 48 hours.
*   If you want to transfer crypto to Alchemy Pay for user, please check [Hiding Receiving Address Page](/docs/off-ramp-hiding-receiving-address-page).

### Request Parameters
| Element | Mandatory | Data Type | Remarks |
| --- | --- | --- | --- |
| appId | Y | string | Unique identifier assigned by Alchemy Pay. You can find it in the merchant backend |
| timestamp | Y | string | Thirteen-digit timestamp |
| type | Y | string | Fixed value: `sell` |
| merchantOrderNo | Y | string | Merchant order number, Alchemy Pay will carry this parameter in the webhook, allowing you to track order information using this parameter. **The merchantOrderNo cannot be duplicated.** |
| sign | Y | string | For the generation rules of the sign, please refer to this [Click Here](/docs/ramp-signature-description). **URL encoding is required when concatenating to the request URL.** |
| fiat | N | string | Fiat currency user received, check the supported fiat currencies by Alchemy Pay [Click Here](/docs/fiat-currency-country-payment-method-coverage-plus-fees-and-limits). Upload this field, users cannot modify the fiat currency. **If use this field, uploading country field is a must.** |
| country | N | string | **Required when uploading the fiat field.** Must correspond to the `fiat` field to be valid. Follow the ISO 3166-1 alpha-2 standard. |
| cryptoAmount | Y | string | The quantity of the cryptocurrency that the user wishes to sell. If passed, users will be unable to modify the cryptocurrency quantity. When passing cryptoAmount, crypto must be passed simultaneously, otherwise it will be meaningless.* |
| crypto | Y | string | The cryptocurrency that the user wants to sell. You can check the cryptocurrencies supported by Alchemy Pay [Click Here](/docs/crypto-currency-coverage). **If passed, users will not be able to select other cryptocurrencies.** |
| network | Y | string | The cryptocurrency network that the user wants to sell. It is recommended to pass both the network and crypto parameters together to accurately limit the cryptocurrency the user can sell. You can check the supported networks [Click Here](/docs/network-code). If passed, users will not be able to modify the network. The crypto and network parameters must match; otherwise, the passed parameters will not take effect.* |
| email | N | string | Email used by the user. When you pass this parameter, we will pre-fill this email, but the user still needs to enter an email verification code to validate the email. |
| token | N | string | If you have already verified the email of your user and wish to skip the email verification process during the Alchemy Pay experience, you can pass this parameter. For the token generation rules, please refer to [Click Here](/docs/login-free-instructions). If the token parameter is uploaded, the email parameter does not need to be uploaded. |
| language | N | string | Language of the ramp page opened by the user. Spanish: `es`, Traditional Chinese: `zh-HK`, English: `en-US`, Vietnamese: `vi`, Indonesian: `id`. eg: `language=en-US` |
| showTable | N | string | If you want the ramp page to only display the off-ramp option, you can pass this parameter: `showTable=sell` |
| callbackUrl | N | string | After the user sells, Alchemy Pay will notify you of the payment result at this address. **URL encoding is required when concatenating to the request URL.** |
| merchantName | N | string | Merchant custom name, when merchants pass this name, the merchant name on the order completion page will be displayed according to this parameter. |
| withdrawUrl | N | string | If you wish for the user to go to your website for withdrawal after creating an order, you can pass this parameter. You can carry your order information in the withdrawUrl, so when Alchemy Pay redirects to this page, you can retrieve the corresponding information for the order. |
| urlType | N | string | APP: `\"app\"` WEB: `\"web\"`. The type of the withdrawUrl that the user will be redirected to. |

---

## 7. API Integration
**Source:** [https://alchemypay.readme.io/docs/api-integration](https://alchemypay.readme.io/docs/api-integration)

### Introduction
AlchemyPay supports three integration methods, and you can integrate according to your own needs:
1. **Standard API Integration:** [Standard API Integration](/docs/standard-api-integration)
    *   After the user confirms the order, they will be redirected to the ACH checkout page to complete the payment.
    *   Only support On-Ramp.
2. **Native API Integration:** [Native API Integration](/docs/native-api-integration)
    *   All pages are designed by the merchant.
    *   Both support On-Ramp and Off-Ramp.

### IP Whitelist
You can configure your server IP in the merchant dashboard, and our system will only accept requests from IPs on the whitelist. Refer to: [Usage Of Merchant Dashboard Ramp](/docs/ramp-merchant-backend).

### Domains
*   **Prod:** `https://openapi.alchemypay.org/`
*   **Test:** `https://openapi-test.alchemypay.org/`

---

## 8. Get Token
**Source:** [https://alchemypay.readme.io/docs/get-token](https://alchemypay.readme.io/docs/get-token)

### Introduction
*   Need to provide the user’s real email address.
*   Use `uid` to generate user token, which is only supported for new users, and users must perform email verification when logging in for the first time.
*   The `accessToken` is valid for 10 days.

### API Description
*   **Request Method:** `POST`
*   **Request Path:** `/open/api/v4/merchant/getToken`

### Request Parameters

#### Header Parameters
| Parameter | Mandatory | Type | Remarks |
| --- | --- | --- | --- |
| appid | Y | string | App unique identifier |
| timestamp | Y | string | Current UTC 13-digit timestamp, valid within 5 minutes |
| sign | Y | string | Signature, you can refer to the signature [Click Here](/docs/api-sign) |

#### Body Parameters
| Parameter | Mandatory | Type | Length | Remarks |
| --- | --- | --- | --- | --- |
| email | Conditional Mandatory | string | / | User's email |
| uid | Conditional Mandatory | string | 36 | User’s UUID from merchant side |

#### Request Parameter Example (email):
```json
{
	"email": "test@gmail.com"
}
```

#### Request Parameter Example (uid):
```json
{
	"uid": "1234567xxxxx"
}
```

### Response Parameters

#### Response Parameter Example (email):
```json
{
    "success": true,
    "returnCode": "0000",
    "returnMsg": "SUCCESS",
    "extend": "",
    "data": {
        "id": "kklzDn3K/BvuSXs559OQfQ==",
        "accessToken": "ACH8945766425@ACH@kklzDn3K/BvuSXs559OQfQ==@PAY@cwqgsiyILMYNuMjhxhaQLpCX1hnntIqfL+V7uEqNu6I=@IO@g5aBrOrzxrfzsqs8W0cKR4VBugBZBSH5gYLOoL1eHICLR3GTygMCaCN3RvIMaeOUmy9PAVmFImjz+4uXR1MpRg==",
        "email": "cwqgsiyILMYNuMjhxhaQLpCX1hnntIqfL+V7uEqNu6I="
    },
    "traceId": "642e6990f3481462c6185b310ba2120b"
}
```

#### Response Parameter Example (uid):
```json
{
    "success": true,
    "returnCode": "0000",
    "returnMsg": "SUCCESS",
    "extend": "",
    "data": {
        "accessToken": "ACH8658667838@ACH@0sf2EDon8eujsasbMDo3g==@PAY@XXpkhtp3Oau+DfgOqwUNUEk1Ijdx7175Cpbcw2sm8hQ=@IO@oKMVGvEf/W9C3QD1/eEsRraWzYaQPJxS9L96NSQWCOheWzsOeRSBmZfxj8Vdu5kpLQy+pymyVbSdtFETC2Znwg==",
        "id": "G0sf2Eon8eujsasbMDo3g=="
    },
    "traceId": "67ff761516e999cf1038d8a2f71e6de7"
}
```

### Error Code
| Code | Description | ReturnMsg |
| --- | --- | --- |
| 3108 | Missing Parameter | Must send one of the parameters |

---

## 9. API Sign
**Source:** [https://alchemypay.readme.io/docs/api-sign](https://alchemypay.readme.io/docs/api-sign)

### Introduction
*   Alchemy Pay will issue a pair of `appId` & `appSecret` for each partner once onboarded. The `appId` is used to identify the partner, while `appSecret` is for signature purposes.
*   `appId` & `appSecret` will be delivered to the partner upon request from Alchemy Pay's operation team. There is currently no online service for self-application.
*   Please do not expose the `appSecret` in any API request.

### Signature Parameters
| Description | Description | Remarks |
| --- | --- | --- |
| timestamp | Thirteen-digit timestamp | 1699261493465 |
| httpMethod | Request Method GET/POST | Request method must be in uppercase |
| requestPath | Request Path | Excluding the domain name |
| bodyString | Request Body | GET: empty, POST: request body |

### Step 1: Generate An Encrypted String
1. The signature string is fixed as follows: `timestamp` + `httpMethod` + `requestPath` + `bodyString`.
2. For the parameters in `requestPath`, `bodyString`, sort them in dictionary order and remove any empty values.
3. Finally, encrypt using HMAC SHA256 with the `SecretKey` and encode it using Base64 to obtain the sign.

#### Signature String Example (POST method):
Example: Create Order
*   **timestamp:** `1699261493465`
*   **httpMethod:** `POST`
*   **requestPath:** `/open/api/v4/merchant/trade/create`
*   **bodyString:**
    ```json
    {
        "side": "BUY",
        "cryptoCurrency": "USDT",
        "address": "TSx82tWNWe5Ns6t3w94Ye3Gt6E5KeHSoP8",
        "network": "TRX",
        "fiatCurrency": "USD",
        "amount": "100",
        "depositType": 2,
        "payWayCode": "10001",
        "alpha2": "US",
        "redirectUrl": "",
        "callbackUrl": "http://payment.jyoumoney.com/alchemyRamp/pay/callback?tradeNo=DZ02207091800356504"
    }
    ```

**(1) Sort bodyString:**
`{"address":"TSx82tWNWe5Ns6t3w94Ye3Gt6E5KeHSoP8","alpha2":"US","amount":"100","callbackUrl":"http://payment.jyoumoney.com/alchemyRamp/pay/callback?tradeNo=DZ02207091800356304","cryptoCurrency":"USDT","depositType":2,"fiatCurrency":"USD","network":"TRX","payWayCode":"10001","side":"BUY"}`

**(2) Signature String:**
`1699261493465POST/open/api/v4/merchant/trade/create{"address":"TSx82tWNWe5Ns6t3w94Ye3Gt6E5KeHSoP8","alpha2":"US","amount":"100","callbackUrl":"http://payment.jyoumoney.com/alchemyRamp/pay/callback?tradeNo=DZ02207091800356304","cryptoCurrency":"USDT","depositType":2,"fiatCurrency":"USD","network":"TRX","payWayCode":"10001","side":"BUY"}`

#### Signature String Example (GET method):
Example: Query Order
*   **timestamp:** `1699261493465`
*   **httpMethod:** `GET`
*   **requestPath:** `/open/api/v4/merchant/query/trade?orderNo=1028577684629876736&side=BUY&email=abc@gamial.com`
*   **bodyString:** *(empty)*

**(1) Sort requestPath:**
`email=abc@gamial.com&orderNo=1028577684629876736&side=BUY`

**(2) Signature String:**
`1699261493465GET/open/api/v4/merchant/query/trade?email=abc@gamil.com&orderNo=1028577684629876736&side=BUY`

### Step Two: Generate Your Signature
Use the encrypted string and secret as parameters to generate a signature as follows:

```java
public class AchSign {

    public static String apiSign(String timestamp, String method, String path, Map<String, String> paramMap, String secretkey) throws NoSuchAlgorithmException, InvalidKeyException {
        String content = timestamp + method.toUpperCase() + path + getJsonBody(paramMap);
        Base64.Encoder base = Base64.getEncoder();
        String signVal = base.encodeToString(sha256(content.getBytes(StandardCharsets.UTF_8), secretkey.getBytes(StandardCharsets.UTF_8)));
        return signVal;
    }

    public static byte[] sha256(byte[] message, byte[] secret) throws NoSuchAlgorithmException, InvalidKeyException {
        Mac sha256_HMAC = Mac.getInstance("HmacSha256");
        SecretKeySpec secretKey = new SecretKeySpec(secret, "HmacSha256");
        sha256_HMAC.init(secretKey);
        return sha256_HMAC.doFinal(message);
    }

    private static String getJsonBody(Map<String,String> parameters) {
        if (parameters == null || parameters.isEmpty()) {
            return "";
        }
        parameters = removeEmptyKeys(parameters);
        parameters = (Map) sortObject(parameters);
        return JSON.toJSONString(parameters);
    }
    
    private static Map removeEmptyKeys(Map map) {
        if (map.isEmpty()) {
            return map;
        }
        Map retMap = new HashMap();
        Iterator<Map.Entry> iterator = map.entrySet().iterator();
        while (iterator.hasNext()) {
            Map.Entry<String, Object> entry = iterator.next();
            if (entry.getValue() != null && !entry.getValue().equals("")) {
                retMap.put(entry.getKey(), entry.getValue());
            }
        }
        return retMap;
    }

    private static Object sortObject(Object obj) {
        if (obj instanceof Map) {
            return sortMap((Map) obj);
        } else if (obj instanceof List) {
            sortList((List) obj);
            return obj;
        }
        return null;
    }

    private static Map sortMap(Map map) {
        if (map.isEmpty()) {
            return null;
        }
        SortedMap<String, Object> sortedMap = new TreeMap<>(removeEmptyKeys(map));
        for (String sortKey : sortedMap.keySet()) {
            if (sortedMap.get(sortKey) instanceof Map) {
                sortedMap.put(sortKey, sortMap((Map) sortedMap.get(sortKey)));
            } else if (sortedMap.get(sortKey) instanceof List) {
                sortedMap.put(sortKey, sortList((List) sortedMap.get(sortKey)));
            }
        }
        return sortedMap;
    }

    private static List sortList(List list) {
        if (list.isEmpty()) {
            return null;
        }
        List objectList = new ArrayList();

        List intList = new ArrayList();
        List floatList = new ArrayList();
        List stringList = new ArrayList();

        List jsonArray = new ArrayList();
        for (Object obj : list) {
            if (obj instanceof Map || obj instanceof List) {
                jsonArray.add(obj);
            } else if (obj instanceof Integer) {
                intList.add(obj);
            } else if (obj instanceof BigDecimal) {
                floatList.add(obj);
            } else if (obj instanceof String) {
                stringList.add(obj);
            } else {
                intList.add(obj);
            }
        }

        Collections.sort(intList);
        Collections.sort(floatList);
        Collections.sort(stringList);

        objectList.addAll(intList);
        objectList.addAll(floatList);
        objectList.addAll(stringList);
        objectList.addAll(jsonArray);

        list.clear();
        list.addAll(objectList);

        List retList = new ArrayList();

        for (Object obj : list) {
            if (obj instanceof Map) {
                retList.add(sortMap((Map) obj));
            } else if (obj instanceof List) {
                retList.add(sortList((List) obj));
            } else {
                retList.add(obj);
            }
        }
        return retList;
    }

    public static void main(String[] args) throws Exception {
        String timestamp = String.valueOf(System.currentTimeMillis());
        String method = "";
        String path = "";
        Map map = new HashMap();
        String secretkey = "";
        String sign = apiSign(timestamp, method, path, map, secretkey);
        System.out.println(timestamp);
        System.out.println(sign);
        System.out.println(URLEncoder.encode(sign));
    }
}
```

---

## 10. Webhook
**Source:** [https://alchemypay.readme.io/docs/webhook](https://alchemypay.readme.io/docs/webhook)

### Interface Description
When users buy or sell coins, we will push order information to merchants based on the results of the transactions.

**Retry Mechanism:** By default, webhooks are sent only once. If needed, please contact us to configure webhook retries with the following intervals: `5 minutes, 15 minutes, 30 minutes, 1 hour, 2 hours, 4 hours, 8 hours`. Retrying will stop once we receive an HTTP `200` response with a `success` message. Currently, webhook retries are only supported for OnRamp.

> [!NOTE]
> ### Recommendation
> We recommend using the webhook in conjunction with the Order Query API.

### Interface Explanation
*   **Request Method:** `POST`
*   **Request Address:** The `callbackUrl` provided by the merchant when placing an order.

#### Header Parameter
| Element | Data Type | Remarks |
| --- | --- | --- |
| timestamp | string | timestamp (used for signature verification) reference [here](/docs/webhook-signature) |

### On Ramp Webhook

#### Body Parameter List
| Element | Data Type | Explanation | Remarks |
| --- | --- | --- | --- |
| appId | string | partner unique ID | |
| orderNo | string | Alchemy Pay Order ID | |
| email | string | end user's email | |
| merchantUid | string | User’s UUID from merchant side | |
| crypto | string | crypto type | |
| cryptoPrice | string | crypto price | |
| cryptoQuantity | string | crypto amount | |
| payType | string | fiat payment method | |
| fiat | string | fiat type | |
| amount | string | fiat amount | |
| payTime | string | fiat payment time | |
| network | string | crypto network | |
| address | string | crypto address | |
| txTime | string | crypto received time | |
| txHash | string | crypto hash | |
| status | string | Order status, send webhook to merchant only when order status is: `PAY_FAIL`, `PAY_SUCCESS`, `FINISHED`. [details](/docs/list-of-order-status#on-ramp) | |
| message | string | Error message for fiat payment failure | |
| merchantOrderNo | string | merchant order ID | |
| networkFee | string | crypto network fee | Blockchain transaction fees |
| rampFee | string | ramp fee | |
| signature | string | This is a deprecated signature field. Please use the `newSignature` field instead. | |
| fiatInUSD | string | fiat amount (valued in USD) | Returned if status is `FINISHED`. |
| rampFeeInUSD | string | service charge (valued in USD) | Returned if status is `FINISHED`. |
| cryptoNetworkFee | string | priced counted on purchased tokens | Returned if status is `FINISHED`. |
| networkFeeInUSD | string | Network fee (priced in USD), calculated as cryptoNetworkFee and priced in USD | Returned if status is `FINISHED`. |
| cryptoAmountInUSDT | string | The token received by user (priced in USDT) | Returned if status is `FINISHED`. |
| rampFeeUnit | string | Unit of Ramp fee, such as USD, INR | |
| newSignature | string | newSignature, reference [here](/docs/webhook-signature) | |

> [!NOTE]
> ### Note:
> 1. For local payment in INR, there is no callback for the completion of fiat payment.
> 2. Failed payment notifications will include two additional fields: `returnCode` (error code for failure) and `returnMsg` (failure reason).

The following parameters are not sent by default and will only be sent if the merchant commission rebate feature is enabled.
| Element | Data Type | Remarks |
| --- | --- | --- |
| createTime | string | Order creation time, format YYYY-MM-DD, HH:MM:SS, e.g., 2021-11-25 10:00:00 |
| tokenAddress | string | Contract address of the token returned when purchasing coins; leave blank if it is a native chain coin |
| alpha2 | string | ISO 3166-1 two-letter country code, such as US/JP, etc. |
| rebateFiatAmount | string | Commission amount, valued in fiat currency. |
| rebateUsdAmount | string | Commission amount, valued in USD. |

#### On Ramp Payload Sample (FINISHED)
```json
{
    "payTime": "2025-10-27 14:31:11",
    "txTime": "2025-10-27 14:37:06",
    "signature": "8740b5ae5fae0559a16bf09e755d***********",
    "networkFee": "0.10092527",
    "rawRampFee": "5.188000",
    "fiatInUSD": "120",
    "network": "LTC",
    "cryptoPrice": "100.92520000",
    "payType": "Apple Pay",
    "rampFee": "5.18000000",
    "appId": "**************",
    "fiat": "USD",
    "newSignature": "M3yP3sMg97cfuwCk/tQkUrr*****************",
    "txHash": "6f3cb23402837e3dbe3e52aff2f995ff********************",
    "email": "H**********@icloud.com",
    "rampFeeInUSD": "5.18",
    "amount": "120.00000000",
    "orderNo": "1432224***********",
    "address": "ltc1q5hs99hj3rq5e04fsr5******************",
    "cryptoNetworkFee": "0.00446791",
    "networkFeeInUSD": "0.45",
    "cryptoAmountInUSDT": "114.36907472",
    "merchantOrderNo": "647b0a96************",
    "crypto": "LTC",
    "rampFeeUnit": "USD",
    "cryptoQuantity": "1.1332055",
    "status": "FINISHED"
}
```

### Off Ramp Webhook

#### Body Parameter List
| Element | Data Type | Remark |
| --- | --- | --- |
| orderNo | string | Alchemy Pay Order ID |
| address | string | ACH address for receiving user tokens |
| payTime | string | The time when ACH starts to transfer fiat to the user's account |
| completeTime | string | The time when this order receives the cryptos |
| merchantOrderNo | string | Merchant order number |
| crypto | string | Crypto name |
| network | string | Network of crypto |
| cryptoPrice | string | Crypto price in fiat type |
| cryptoAmount | string | Order's crypto amount |
| fiatAmount | string | The fiat amount user will receive, contains ramp fee |
| appId | string | appID |
| fiat | string | fiat currency |
| txHash | string | Token transferred txHash |
| email | string | User's email |
| signature | string | callback signature: `appId+orderNo+crypto+network+address` signed using API Sign rules |
| status | string | Order Status, [details](/docs/list-of-order-status#off-ramp) |
| orderAddress | string | Url to the order detail page |
| cryptoacturalAmount | string | The actual received crypto amount |
| rampfee | string | Ramp fee, based on fiat type |
| receiptTime | string | Time of user receives payment |
| paymentType | string | `card` (transfer to the user's card) or `account` (transfer to user bank account) |
| newSignature | string | newSignature, reference [here](https://dash.readme.com/project/alchemypay/v4.0.2/docs/webhook-signature) |

> [!NOTE]
> ### Note:
> Different statuses may have empty values and fields.

#### Off Ramp Payload Sample (Payment Success)
```json
{
    "orderAddress": "https://ramp.alchemypay.org/#/sellOrder?sellOrderId=1432901579********",
    "orderNo": "1432901579**********",
    "address": "************************",
    "fiatRate": "0.8580540000",
    "payTime": "2025-10-29 09:54:22",
    "signature": "6d465fd********5627276d03",
    "completeTime": "2025-10-29 09:54:20",
    "merchantOrderNo": "6f34ca6****************",
    "crypto": "USDT",
    "network": "TRX",
    "paymentType": "10010",
    "cryptoPrice": "1.0000000000",
    "receiptTime": "2025-10-29 09:58:04",
    "rampFee": "15.0700000000",
    "cryptoAmount": "550.0000000000",
    "fiatAmount": "471.9297000000",
    "appId": "B93LC4********",
    "name": "Ed**************",
    "fiat": "EUR",
    "cryptoActualAmount": "550.0000000000",
    "txHash": "c67ba35a403f0bd8a946d76f546fb0fc09ce6c7f*************",
    "email": "e************@gmail.com",
    "account": "************4965",
    "status": "4"
}
```

---

## 11. Webhook Signature
**Source:** [https://alchemypay.readme.io/docs/webhook-signature](https://alchemypay.readme.io/docs/webhook-signature)

### Signature Fields
*   **Timestamp:** Retrieved from the asynchronous notification request header
*   **Request Method:** `POST`
*   **Request Path:** The `callbackUrl` provided by the merchant when placing an order (only the path without the domain)
*   **Request Body:** Request parameters

1. Sort the request parameters in ascending alphabetical order by parameter name, excluding empty values, `signature`, and `newSignature`.
2. Generate the string to be signed with the fixed order: `timestamp` + `requestMethod` + `requestPath` + `requestBody`.

### Generate Signature
```java
public class SignCheck {

    public static String signCheck(String content, String secretkey) throws NoSuchAlgorithmException, InvalidKeyException {
        Base64.Encoder base = Base64.getEncoder();
        String signVal = base.encodeToString(sha256(content.getBytes(StandardCharsets.UTF_8), secretkey.getBytes(StandardCharsets.UTF_8)));
        return signVal;
    }

    public static byte[] sha256(byte[] message, byte[] secret) throws NoSuchAlgorithmException, InvalidKeyException {
        Mac sha256_HMAC = Mac.getInstance("HmacSha256");
        SecretKeySpec secretKey = new SecretKeySpec(secret, "HmacSha256");
        sha256_HMAC.init(secretKey);
        return sha256_HMAC.doFinal(message);
    }

    public static void main(String[] args) throws Exception {
        String content = "1700549311596POST/onRamp/callback{\"address\": \"TGNMkik3nPaioVJdkE7qEixWr9cUvsyT5g\",\"crypto\": \"USDT\",\"fiat\": \"USD\"}";
        String secretkey = "XXXXX";
        String sign = signCheck(content, secretkey);
        System.out.println(sign);
    }
}
```

### Generate the string to be signed "Example"

1. **Retrieve the webhook parameters:**
```json
{
	"amount": "15.00000000",
	"orderNo": "***",
	"address": "***",
	"payTime": "2024-09-27 17:59:27",
	"signature": "f13fb8137f2c999c5932261de9bc8668b0a7b014",
	"rawRampFee": "0.998500",
	"merchantOrderNo": "***",
	"crypto": "USDT",
	"network": "TRX",
	"rampFeeUnit": "USD",
	"cryptoPrice": "0.00000000",
	"payType": "CREDIT_CARD",
	"rampFee": "0.99000000",
	"cryptoQuantity": "12.93",
	"appId": "f83Is2y7L425rxl8",
	"fiat": "USD",
	"newSignature": "+T2BJ1S2X+ffRXoF+q5c/aqgZSyjGXt7Oh073UXLti0=",
	"email": "***@gmail.com",
	"status": "PAY_SUCCESS",
	"rampFeeInUSD": "0.99"
}
```

2. **Remove empty values, `signature` and `newSignature`, then sort the parameters:**
```json
{
	"address": "***",
	"amount": "15.00000000",
	"appId": "f83Is2y7L425rxl8",
	"crypto": "USDT",
	"cryptoPrice": "0.00000000",
	"cryptoQuantity": "12.93",
	"email": "***@gmail.com",
	"fiat": "USD",
	"merchantOrderNo": "***",
	"network": "TRX",
	"orderNo": "***",
	"payTime": "2024-09-27 17:59:27",
	"payType": "CREDIT_CARD",
	"rampFee": "0.99000000",
	"rampFeeInUSD": "0.99",
	"rampFeeUnit": "USD",
	"rawRampFee": "0.998500",
	"status": "PAY_SUCCESS"
}
```

3. **Retrieve the `timestamp` parameter from the request header and the `callbackUrl` path:**
*   **timestamp:** `1727431167633`
*   **requestPath:** `/alchemypay-on-ramp`

4. **Concatenate the string to be signed:**
`1727431167633POST/alchemypay-on-ramp{"address":"***","amount":"15.00000000","appId":"f83Is2y7L425rxl8","crypto":"USDT","cryptoPrice":"0.00000000","cryptoQuantity":"12.93","email":"***@gmail.com","fiat":"USD","merchantOrderNo":"***","network":"TRX","orderNo":"***","payTime":"2024-09-27 17:59:27","payType":"CREDIT_CARD","rampFee":"0.99000000","rampFeeInUSD":"0.99","rampFeeUnit":"USD","rawRampFee":"0.998500","status":"PAY_SUCCESS"}`

---

## 12. List of Fiat Currencies, Cryptocurrencies, and KYC
**Source:** [https://alchemypay.readme.io/docs/crypto-currency-coverage](https://alchemypay.readme.io/docs/crypto-currency-coverage)

### On- & Off- Ramp Crypto Currency Coverage
Check supported crypto and network for onramp and offramp via the Notion directory:
[https://alchemypay.notion.site/Crypto-Chain-Coverages-419fc088f0704db8abbc9cfb77382dc1](https://alchemypay.notion.site/Crypto-Chain-Coverages-419fc088f0704db8abbc9cfb77382dc1)
