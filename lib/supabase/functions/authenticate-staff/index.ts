import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS, status: 204 });
  }

  try {
    // Parse request body
    const { pin, outletId } = await req.json();

    if (!pin || typeof pin !== "string" || pin.length !== 4) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "Invalid PIN format. Must be 4 digits.",
        }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "content-type": "application/json" },
        }
      );
    }

    // Create Supabase client with service role to bypass RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log(`🔐 Authenticating staff with PIN for outlet: ${outletId || "ANY"}`);

    // Validate outlet is provided
    if (!outletId) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "Outlet selection is required.",
        }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "content-type": "application/json" },
        }
      );
    }

    // Find staff members for this outlet with matching PIN
    const { data: staffMatches, error: lookupError } = await supabase
      .from("staff")
      .select("id, full_name, pin_code, active, outlet_id, role_id")
      .eq("outlet_id", outletId)
      .eq("pin_code", pin)
      .eq("active", true);

    if (lookupError) {
      console.error("❌ Staff lookup error:", lookupError);
      return new Response(
        JSON.stringify({
          success: false,
          message: "Authentication failed. Please try again.",
        }),
        {
          status: 500,
          headers: { ...CORS_HEADERS, "content-type": "application/json" },
        }
      );
    }

    // No staff found with this PIN at this outlet
    if (!staffMatches || staffMatches.length === 0) {
      console.log(`❌ Invalid PIN for outlet ${outletId}`);
      return new Response(
        JSON.stringify({
          success: false,
          message: "Invalid PIN or no access to this outlet.",
        }),
        {
          status: 401,
          headers: { ...CORS_HEADERS, "content-type": "application/json" },
        }
      );
    }

    // Check for duplicate PINs within this outlet
    if (staffMatches.length > 1) {
      console.log(`❌ Duplicate PIN detected for outlet ${outletId} (${staffMatches.length} matches)`);
      return new Response(
        JSON.stringify({
          success: false,
          message: "PIN is not unique. Please contact your administrator to assign unique PINs.",
        }),
        {
          status: 409,
          headers: { ...CORS_HEADERS, "content-type": "application/json" },
        }
      );
    }

    // Exactly one match - proceed with authentication
    const staff = staffMatches[0];
    const staffId = staff.id;
    const staffName = staff.full_name;

    // Get role permission level if role_id exists
    let permissionLevel = 1; // Default permission level
    if (staff.role_id) {
      const { data: roleData } = await supabase
        .from("roles")
        .select("permission_level")
        .eq("id", staff.role_id)
        .maybeSingle();

      if (roleData?.permission_level) {
        permissionLevel = roleData.permission_level;
      }
    }

    // Get all outlets this staff member has access to via staff_outlets junction table
    const { data: allStaffOutlets } = await supabase
      .from("staff_outlets")
      .select("outlet_id")
      .eq("staff_id", staffId)
      .eq("active", true);

    // Include the primary outlet from staff table + any additional outlets from junction table
    const outletIdsFromJunction = allStaffOutlets?.map((so) => so.outlet_id) || [];
    const associatedOutletIds = Array.from(new Set([outletId, ...outletIdsFromJunction]));

    // Update last_login_at
    await supabase
      .from("staff")
      .update({ last_login_at: new Date().toISOString() })
      .eq("id", staffId);

    console.log(`✅ Authentication successful: ${staffName} (${staffId}) → ${outletId}`);

    // Return authenticated staff data
    return new Response(
      JSON.stringify({
        success: true,
        message: "Authentication successful",
        staff: {
          id: staffId,
          name: staffName,
          outletId: outletId,
          roleId: staff.role_id,
          permissionLevel: permissionLevel,
          associatedOutletIds: associatedOutletIds,
        },
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      }
    );
  } catch (error) {
    console.error("❌ Unexpected error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        message: "An unexpected error occurred. Please try again.",
      }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      }
    );
  }
});
