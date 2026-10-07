package com.zameel.app

import com.android.billingclient.api.*
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

/** Tokens leave this bridge only through Flutter's authenticated verification path. */
class ZameelPlayBilling(private val activity: MainActivity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "zameel/play_billing")
    private val products = mutableMapOf<String, ProductDetails>()
    private val client = BillingClient.newBuilder(activity).setListener { result, purchases ->
        channel.invokeMethod("updates", mapOf("code" to result.responseCode,
            "purchases" to (purchases ?: emptyList()).map { serialize(it) }))
    }.enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection().build()
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> if(client.isReady) result.success(true) else client.startConnection(object: BillingClientStateListener {
                    override fun onBillingServiceDisconnected() {}
                    override fun onBillingSetupFinished(r: BillingResult) {
                        if(r.responseCode == BillingClient.BillingResponseCode.OK) result.success(true)
                        else result.error("billing_unavailable", "Google Play unavailable", null)
                    }
                })
                "products" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    if(ids.isEmpty() || ids.size > 31 || ids.any { !known(it) }) {
                        result.error("invalid_products", "Invalid products", null)
                    } else client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(ids.map {
                        QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(BillingClient.ProductType.INAPP).build()
                    }).build()) { r, response ->
                        if(r.responseCode != BillingClient.BillingResponseCode.OK) result.error("product_unavailable", "Products unavailable", null)
                        else {
                            products.putAll(response.productDetailsList.associateBy { it.productId })
                            result.success(response.productDetailsList.mapNotNull { p ->
                                val offers = p.oneTimePurchaseOfferDetailsList.orEmpty()
                                val offer = if(offers.size > 1) null else offers.singleOrNull() ?: p.oneTimePurchaseOfferDetails
                                offer?.let { mapOf("id" to p.productId, "price" to it.formattedPrice, "currency" to it.priceCurrencyCode) }
                            })
                        }
                    }
                }
                "buy" -> {
                    val id = call.argument<String>("id").orEmpty()
                    val account = call.argument<String>("account").orEmpty()
                    val profile = call.argument<String>("profile").orEmpty()
                    val product = products[id]
                    val offers = product?.oneTimePurchaseOfferDetailsList.orEmpty()
                    val offer = if(offers.size > 1) null else offers.singleOrNull() ?: product?.oneTimePurchaseOfferDetails
                    if(product == null || offer == null || !Regex("^[a-f0-9]{64}$").matches(account) || !Regex("^[a-f0-9]{64}$").matches(profile)) {
                        result.error("purchase_unavailable", "Purchase unavailable", null)
                    } else {
                        val params = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product)
                        offer.offerToken?.takeIf { it.isNotEmpty() }?.let { params.setOfferToken(it) }
                        val r = client.launchBillingFlow(activity, BillingFlowParams.newBuilder()
                            .setProductDetailsParamsList(listOf(params.build()))
                            .setObfuscatedAccountId(account).setObfuscatedProfileId(profile).build())
                        result.success(r.responseCode)
                    }
                }
                "recover" -> client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { r, purchases ->
                    if(r.responseCode == BillingClient.BillingResponseCode.OK) result.success(purchases.map { serialize(it) })
                    else result.error("recovery_unavailable", "Purchase recovery unavailable", null)
                }
                else -> result.notImplemented()
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null); client.endConnection() }
    private fun known(id: String) = id == "zameel_verification_month" ||
        Regex("^zameel_promotion_(0[1-9]|[12][0-9]|30)_days$").matches(id)
    private fun serialize(p: Purchase): Map<String, Any?> = mapOf("token" to p.purchaseToken,
        "products" to p.products, "state" to p.purchaseState,
        "binding" to p.accountIdentifiers?.obfuscatedProfileId)
}
