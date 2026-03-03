import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-max-age': '86400',
};

interface AuthRequest {
  pin: string;
  outletId: string;
}

interface AuthResponse {
  success: boolean;
  message?: string;
  staff?: {
    id: string;
    name: string;
    pin: string;
    associatedOutletIds: string[];
    roleId: string | null;
    roleName: string | null;
    permissionLevel: number;
  };
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ success: false, message: 'Method not allowed' }),
        { status: 405, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
      );
    }

    // Parse request body
    const { pin, outletId }: AuthRequest = await req.json();

    // Validate input
    if (!pin || !outletId) {
      return new Response(
        JSON.stringify({ success: false, message: 'PIN and outletId are required' }),
        { status: 400, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
      );
    }

    // Create Supabase client with service role (bypasses RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Step 1: Find staff member by PIN
    const { data: staffData, error: staffError } = await supabaseAdmin
      .from('staff')
      .select('id, name, pin')
      .eq('pin', pin)
      .eq('active', true)
      .single();

    if (staffError || !staffData) {
      console.error('Staff lookup error:', staffError);
      return new Response(
        JSON.stringify({ success: false, message: 'Invalid PIN' }),
        { status: 401, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
      );
    }

    console.log(`✓ Found staff member: ${staffData.name} (ID: ${staffData.id})`);

    // Step 2: Check staff_outlets association for the specific outlet
    const { data: outletAssociation, error: associationError } = await supabaseAdmin
      .from('staff_outlets')
      .select('role_id')
      .eq('staff_id', staffData.id)
      .eq('outlet_id', outletId)
      .eq('active', true)
      .single();

    if (associationError || !outletAssociation) {
      console.error('Outlet association error:', associationError);
      return new Response(
        JSON.stringify({ success: false, message: 'You do not have access to this outlet' }),
        { status: 403, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
      );
    }

    console.log(`✓ Staff is associated with outlet: ${outletId}`);

    // Step 3: Get ALL outlet associations for this staff member
    const { data: allAssociations, error: allAssociationsError } = await supabaseAdmin
      .from('staff_outlets')
      .select('outlet_id')
      .eq('staff_id', staffData.id)
      .eq('active', true);

    if (allAssociationsError) {
      console.error('Error fetching all associations:', allAssociationsError);
    }

    const associatedOutletIds = allAssociations?.map((a) => a.outlet_id) || [outletId];

    // Step 4: Get role information (if role_id exists)
    let roleName: string | null = null;
    let permissionLevel = 1; // Default level

    if (outletAssociation.role_id) {
      const { data: roleData, error: roleError } = await supabaseAdmin
        .from('roles')
        .select('name, level')
        .eq('id', outletAssociation.role_id)
        .single();

      if (!roleError && roleData) {
        roleName = roleData.name;
        permissionLevel = roleData.level || 1;
        console.log(`✓ Role: ${roleName} (Level: ${permissionLevel})`);
      }
    }

    // Step 5: Return authenticated staff data
    const response: AuthResponse = {
      success: true,
      staff: {
        id: staffData.id,
        name: staffData.name,
        pin: staffData.pin,
        associatedOutletIds,
        roleId: outletAssociation.role_id,
        roleName,
        permissionLevel,
      },
    };

    console.log(`✅ Authentication successful for ${staffData.name}`);

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { ...CORS_HEADERS, 'content-type': 'application/json' },
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({ success: false, message: 'Internal server error' }),
      { status: 500, headers: { ...CORS_HEADERS, 'content-type': 'application/json' } }
    );
  }
});
