// Supabase Edge Function: loyalty-proxy
// Consolidated loyalty logic that handles all business rules and Oliver's API integration
// All loyalty business logic is centralized here for better maintainability

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, role",
  "access-control-allow-methods": "GET, POST, PUT, OPTIONS",
  "access-control-max-age": "86400",
};

const BASE_URL = "https://api.oliversgroup.co.uk";
const ADMIN_TOKEN = Deno.env.get("LOYALTY_ADMIN_TOKEN");

console.log("🔐 Admin token present?", Boolean(ADMIN_TOKEN), "length:", ADMIN_TOKEN?.length);

if (!ADMIN_TOKEN) {
  console.error("❌ LOYALTY_ADMIN_TOKEN is missing");
}

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });

// Helper to parse customer data from Oliver's API into normalized format
function parseCustomer(raw: any): any {
  const fullName = raw.fullName?.toString() || '';
  const firstName = raw.firstName?.toString() || '';
  const lastName = raw.lastName?.toString() || '';
  const name = fullName || [firstName, lastName].filter(s => s).join(' ') || 'Customer';

  return {
    id: raw._id?.toString() || raw.id?.toString() || '',
    fullName: name,
    email: raw.email?.toString() || null,
    phone: raw.phoneNumber?.toString() || raw.phone?.toString() || null,
    identifier: raw.identifier?.toString() || raw.cardId?.toString() || null,
    points: raw.activePoints || raw.totalPoints || raw.points || 0,
  };
}

// Helper to parse rewards (offers or coupons)
function parseCustomers(rawResponse: any): any[] {
  console.log('🔍 Parsing customer response:', JSON.stringify(rawResponse).substring(0, 500));

  const candidates: any[] = [];

  const pushAll = (list: any) => {
    if (Array.isArray(list)) {
      candidates.push(...list);
    }
  };

  if (Array.isArray(rawResponse)) pushAll(rawResponse);
  if (rawResponse?.customers) pushAll(rawResponse.customers);
  if (rawResponse?.data) {
    pushAll(rawResponse.data);
    if (rawResponse.data.customers) pushAll(rawResponse.data.customers);
    if (rawResponse.data.users) pushAll(rawResponse.data.users);
    if (rawResponse.data.data) pushAll(rawResponse.data.data);
    if (rawResponse.data.user) candidates.push(rawResponse.data.user);
  }
  if (rawResponse?.user) candidates.push(rawResponse.user);

  if (candidates.length === 0 && rawResponse && typeof rawResponse === 'object') {
    candidates.push(rawResponse);
  }

  console.log(`📊 Found ${candidates.length} customer(s) to parse`);

  return candidates.map((raw: any) => {
    const fullName = raw.fullName?.toString() || raw.full_name?.toString() || raw.name?.toString();
    const firstName = raw.firstName?.toString();
    const lastName = raw.lastName?.toString();
    const name = fullName || [firstName, lastName].filter(Boolean).join(' ') || 'Customer';
    const identifier = raw.identifier || raw.barCode || raw.barcode || raw.cardNumber || raw.cardId;

    return {
      id: raw.id?.toString() || raw._id?.toString() || '',
      fullName: name,
      email: raw.email?.toString() || null,
      phone: raw.phoneNumber?.toString() || raw.phone?.toString() || null,
      identifier: identifier?.toString() || null,
      points: Number(raw.activePoints ?? raw.totalPoints ?? raw.points ?? raw.loyaltyPoints ?? 0),
    };
  });
}

function parseRewards(list: any[], type: 'offer' | 'coupon'): any[] {
  return list.map((raw) => {
    const discountType = (raw.discountType || raw.type || 'fixed').toString().toLowerCase();
    const value = raw.discountValue || raw.value || 0;
    return {
      id: raw.id?.toString() || '',
      type,
      name: raw.name?.toString() || 'Reward',
      description: raw.description?.toString() || null,
      discountType: discountType.includes('percent') ? 'percentage' : 'fixed',
      discountValue: Number(value),
    };
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const url = new URL(req.url);
  let action = url.searchParams.get("action");
  let requestBody = null;

  console.log("📥 Incoming request", {
    method: req.method,
    url: req.url,
    search: url.search,
  });

  // Parse request body for POST/PUT
  if (req.method === "POST" || req.method === "PUT") {
    try {
      requestBody = await req.json();
      console.log("📋 Parsed request body:", requestBody);
      action = requestBody.action || action;
    } catch (e) {
      console.error("❌ Failed to parse JSON body:", e);
      return jsonResponse({
        error: "Invalid JSON body",
        detail: String(e),
      }, 400);
    }
  }

  if (!action) {
    return jsonResponse({
      error: "Missing action",
      detail: "action is required in request body (POST/PUT) or query params (GET)",
      method: req.method,
    }, 400);
  }

  if (!ADMIN_TOKEN) {
    console.error("❌ LOYALTY_ADMIN_TOKEN not configured");
    return jsonResponse({
      error: "Server configuration error",
      detail: "LOYALTY_ADMIN_TOKEN not configured",
    }, 500);
  }

  try {
    switch (action) {
      case "customer": {
        // Find customer by identifier (barcode/card number)
        const identifier = url.searchParams.get("identifier") || requestBody?.identifier;
        if (!identifier) {
          return jsonResponse({ error: "identifier required" }, 400);
        }

        const upstreamUrl = `${BASE_URL}/api/admin/user-barcode/${encodeURIComponent(identifier)}?page=1&limit=10`;
        console.log("🔍 Customer lookup:", { upstreamUrl });

        const upstream = await fetch(upstreamUrl, {
          headers: {
            authorization: `Bearer ${ADMIN_TOKEN}`,
            role: "admin",
          },
        });

        const bodyText = await upstream.text();
        console.log("📥 Customer lookup response:", { 
          status: upstream.status, 
          body: bodyText.substring(0, 400) 
        });

        let rawData;
        try {
          rawData = bodyText ? JSON.parse(bodyText) : null;
        } catch (e) {
          console.error("❌ Failed to parse customer response");
          return jsonResponse({
            error: "Invalid response from loyalty provider",
            detail: bodyText.substring(0, 400),
          }, 502);
        }

        if (!upstream.ok) {
          return jsonResponse({
            error: "Failed to find customer",
            detail: rawData,
          }, upstream.status);
        }

        // Parse and normalize customer data
        const customers = parseCustomers(rawData);
        console.log(`✅ Found ${customers.length} customer(s)`);
        return jsonResponse({ customers }, 200);
      }

      case "rewards": {
        // Get available rewards (offers + coupons) for a customer at a restaurant
        const userId = url.searchParams.get("userId") || requestBody?.userId;
        const restaurantId = url.searchParams.get("restaurantId") || requestBody?.restaurantId;

        console.log(`🎁 Rewards lookup: userId=${userId}, restaurantId=${restaurantId}`);

        if (!userId || !restaurantId) {
          const missing = [];
          if (!userId) missing.push("userId");
          if (!restaurantId) missing.push("restaurantId");

          return jsonResponse({
            error: "Missing required parameters",
            detail: `Missing: ${missing.join(", ")}`,
            received: { action, userId: userId || null, restaurantId: restaurantId || null },
          }, 400);
        }

        const offersUrl = `${BASE_URL}/api/user/restaurant-offers?restaurantId=${encodeURIComponent(restaurantId)}&userId=${encodeURIComponent(userId)}`;
        const couponsUrl = `${BASE_URL}/api/user/coupons?userId=${encodeURIComponent(userId)}`;

        const [offersRes, couponsRes] = await Promise.all([
          fetch(offersUrl, {
            headers: { authorization: `Bearer ${ADMIN_TOKEN}`, role: "admin" },
          }),
          fetch(couponsUrl, {
            headers: { authorization: `Bearer ${ADMIN_TOKEN}`, role: "admin" },
          }),
        ]);

        const offersText = await offersRes.text();
        const couponsText = await couponsRes.text();

        console.log("📥 Rewards responses:", {
          offersStatus: offersRes.status,
          couponsStatus: couponsRes.status,
        });

        let offersData, couponsData;
        try {
          offersData = offersText ? JSON.parse(offersText) : null;
        } catch (e) {
          console.error("❌ Failed to parse offers response");
          offersData = null;
        }

        try {
          couponsData = couponsText ? JSON.parse(couponsText) : null;
        } catch (e) {
          console.error("❌ Failed to parse coupons response");
          couponsData = null;
        }

        if (!offersRes.ok || !couponsRes.ok) {
          return jsonResponse({
            error: "Failed to fetch rewards",
            detail: "Upstream API error",
            upstreamStatus: {
              offers: offersRes.status,
              coupons: couponsRes.status,
            },
          }, 502);
        }

        // Parse offers and coupons into normalized format
        const offersRaw = Array.isArray(offersData) ? offersData : (offersData?.offers || offersData?.data || []);
        const couponsRaw = Array.isArray(couponsData) ? couponsData : (couponsData?.data || couponsData?.coupons || []);

        const offers = parseRewards(offersRaw, 'offer');
        const coupons = parseRewards(couponsRaw, 'coupon');

        console.log(`✅ Loaded ${offers.length} offers and ${coupons.length} coupons`);
        return jsonResponse({ offers, coupons }, 200);
      }

      case "complete_payment": {
        // Handle complete payment flow: award points + record reward redemption
        if (!requestBody) {
          return jsonResponse({ error: "Request body required" }, 400);
        }

        const {
          orderId,
          userId,
          restaurantId,
          totalAmount,
          pointsPerPound = 1.0,
          reward, // { id, type: 'offer' | 'coupon', name }
        } = requestBody;

        // Validate required fields
        if (!orderId || !userId || !restaurantId || totalAmount == null) {
          return jsonResponse({
            error: "Missing required fields",
            detail: "orderId, userId, restaurantId, and totalAmount are required",
          }, 400);
        }

        const pointsToAward = Math.floor(totalAmount * pointsPerPound);

        console.log(`💰 Complete payment for order ${orderId}:`, {
          userId,
          restaurantId,
          totalAmount,
          pointsToAward,
          reward: reward || 'none',
        });

        const results: any = {
          orderId,
          pointsAwarded: false,
          rewardRecorded: false,
          errors: [],
        };

        // Step 1: Award points
        if (pointsToAward > 0) {
          try {
            const pointsPayload = {
              userId,
              type: 'earn',
              restaurantId,
              points: pointsToAward,
              orderDetails: `FlowTill POS | Order #${orderId.substring(0, 8)} | Bill £${totalAmount.toFixed(2)}`,
            };

            console.log("🎯 Awarding points:", pointsPayload);

            const pointsRes = await fetch(`${BASE_URL}/api/admin/points-history`, {
              method: "POST",
              headers: {
                authorization: `Bearer ${ADMIN_TOKEN}`,
                role: "admin",
                "content-type": "application/json",
                "accept": "application/json",
              },
              body: JSON.stringify(pointsPayload),
            });

            const pointsText = await pointsRes.text();
            console.log("📥 Points award response:", {
              status: pointsRes.status,
              body: pointsText.substring(0, 400),
            });

            if (pointsRes.ok) {
              results.pointsAwarded = true;
              results.pointsAwardedData = pointsText ? JSON.parse(pointsText) : null;
              console.log("✅ Points awarded successfully");
            } else {
              results.errors.push({
                step: 'points_award',
                status: pointsRes.status,
                detail: pointsText,
              });
              console.error("❌ Failed to award points:", pointsRes.status);
            }
          } catch (e) {
            results.errors.push({
              step: 'points_award',
              error: String(e),
            });
            console.error("❌ Exception awarding points:", e);
          }
        }

        // Step 2: Record reward redemption (if applicable)
        if (reward?.id && reward?.type) {
          try {
            if (reward.type === 'offer') {
              const offerPayload = {
                userId,
                offerId: reward.id,
                status: 'redeemed',
                orderId,
              };

              console.log("🎟️ Recording offer redemption:", offerPayload);

              const offerRes = await fetch(`${BASE_URL}/api/user/offer-history`, {
                method: "POST",
                headers: {
                  authorization: `Bearer ${ADMIN_TOKEN}`,
                  role: "admin",
                  "content-type": "application/json",
                },
                body: JSON.stringify(offerPayload),
              });

              const offerText = await offerRes.text();
              console.log("📥 Offer history response:", {
                status: offerRes.status,
                body: offerText.substring(0, 400),
              });

              if (offerRes.ok) {
                results.rewardRecorded = true;
                console.log("✅ Offer redemption recorded");
              } else {
                results.errors.push({
                  step: 'offer_history',
                  status: offerRes.status,
                  detail: offerText,
                });
              }
            } else if (reward.type === 'coupon') {
              // Record coupon history
              const couponPayload = {
                userId,
                couponId: reward.id,
                status: 'redeemed',
                orderId,
              };

              console.log("🎟️ Recording coupon redemption:", couponPayload);

              const couponRes = await fetch(`${BASE_URL}/api/user/coupon-history`, {
                method: "POST",
                headers: {
                  authorization: `Bearer ${ADMIN_TOKEN}`,
                  role: "admin",
                  "content-type": "application/json",
                },
                body: JSON.stringify(couponPayload),
              });

              const couponText = await couponRes.text();
              console.log("📥 Coupon history response:", {
                status: couponRes.status,
                body: couponText.substring(0, 400),
              });

              // Scratch coupon to mark as used
              console.log("🔨 Scratching coupon:", reward.id);
              const scratchRes = await fetch(`${BASE_URL}/api/user/coupons-scratch/${encodeURIComponent(reward.id)}`, {
                method: "PUT",
                headers: {
                  authorization: `Bearer ${ADMIN_TOKEN}`,
                  role: "admin",
                  "content-type": "application/json",
                },
                body: JSON.stringify({ status: 'redeemed' }),
              });

              const scratchText = await scratchRes.text();
              console.log("📥 Scratch coupon response:", {
                status: scratchRes.status,
                body: scratchText.substring(0, 400),
              });

              if (couponRes.ok && scratchRes.ok) {
                results.rewardRecorded = true;
                console.log("✅ Coupon redemption recorded and scratched");
              } else {
                results.errors.push({
                  step: 'coupon_redemption',
                  couponHistoryStatus: couponRes.status,
                  scratchStatus: scratchRes.status,
                  details: { coupon: couponText, scratch: scratchText },
                });
              }
            }
          } catch (e) {
            results.errors.push({
              step: 'reward_recording',
              error: String(e),
            });
            console.error("❌ Exception recording reward:", e);
          }
        }

        console.log("🏁 Payment completion results:", results);
        return jsonResponse(results, results.errors.length === 0 ? 200 : 207); // 207 = Multi-Status
      }

      // Legacy actions for backward compatibility (can be removed once complete_payment is fully adopted)
      case "points_award": {
        if (!requestBody) return jsonResponse({ error: "Request body required" }, 400);

        const { action: _, ...payload } = requestBody;

        console.log("🎯 Awarding loyalty points (admin)", {
          userId: payload.userId,
          restaurantId: payload.restaurantId,
          points: payload.points,
        });

        const upstream = await fetch(`${BASE_URL}/api/admin/points-history`, {
          method: "POST",
          headers: {
            authorization: `Bearer ${ADMIN_TOKEN}`,
            role: "admin",
            "content-type": "application/json",
            "accept": "application/json",
          },
          body: JSON.stringify(payload),
        });

        const text = await upstream.text();

        console.log("📥 Admin points response", {
          status: upstream.status,
          body: text.substring(0, 300),
        });

        let data;
        try {
          data = text ? JSON.parse(text) : null;
        } catch {
          data = { raw: text };
        }

        return jsonResponse(data, upstream.status);
      }

      case "offer_history": {
        if (!requestBody) return jsonResponse({ error: "Request body required" }, 400);
        const { action: _, ...forwardBody } = requestBody;

        const upstream = await fetch(`${BASE_URL}/api/user/offer-history`, {
          method: "POST",
          headers: {
            authorization: `Bearer ${ADMIN_TOKEN}`,
            role: "admin",
            "content-type": "application/json",
          },
          body: JSON.stringify(forwardBody),
        });

        const data = await upstream.json();
        return jsonResponse(data, upstream.status);
      }

      case "coupon_history": {
        if (!requestBody) return jsonResponse({ error: "Request body required" }, 400);
        const { action: _, ...forwardBody } = requestBody;

        const upstream = await fetch(`${BASE_URL}/api/user/coupon-history`, {
          method: "POST",
          headers: {
            authorization: `Bearer ${ADMIN_TOKEN}`,
            role: "admin",
            "content-type": "application/json",
          },
          body: JSON.stringify(forwardBody),
        });

        const data = await upstream.json();
        return jsonResponse(data, upstream.status);
      }

      case "coupon_scratch": {
        const id = requestBody?.id || url.searchParams.get("id");
        if (!id) return jsonResponse({ error: "id required" }, 400);
        if (!requestBody) return jsonResponse({ error: "Request body required" }, 400);

        const { action: _, id: __, ...forwardBody } = requestBody;

        const upstream = await fetch(`${BASE_URL}/api/user/coupons-scratch/${encodeURIComponent(id)}`, {
          method: "PUT",
          headers: {
            authorization: `Bearer ${ADMIN_TOKEN}`,
            role: "admin",
            "content-type": "application/json",
          },
          body: JSON.stringify(forwardBody),
        });

        const data = await upstream.json();
        return jsonResponse(data, upstream.status);
      }

      default:
        return jsonResponse({ error: "Unknown action" }, 400);
    }
  } catch (err) {
    console.error("❌ Proxy error:", err);
    return jsonResponse({ error: "Proxy failed", detail: String(err) }, 500);
  }
});
