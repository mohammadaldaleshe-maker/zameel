export function orderFinance(order, receipt) {
 if (!receipt.order_id || order.orderId !== receipt.order_id || !order.lineItems?.some(x=>x.productId===receipt.product_id)) throw Error('order_binding_mismatch');
 const money=(m)=>{
  if(!m||!/^[A-Z]{3}$/.test(m.currencyCode)||!/^\d+$/.test(String(m.units??'0'))||!Number.isInteger(m.nanos??0)||(m.nanos??0)<0||(m.nanos??0)>999999999)throw Error('invalid_order_money');
  return {currency:m.currencyCode,value:BigInt(m.units??'0').toString()+'.'+String(m.nanos??0).padStart(9,'0')};
 };
 const gross=money(order.total), tax=money(order.tax),net=money(order.developerRevenueInBuyerCurrency);
 if(gross.currency!==tax.currency||gross.currency!==net.currency)throw Error('order_currency_mismatch');
 return {intent_id:receipt.intent_id,order_id:order.orderId,currency:gross.currency,gross:gross.value,tax:tax.value,developer_revenue:net.value,checked_at:new Date().toISOString()};
}
