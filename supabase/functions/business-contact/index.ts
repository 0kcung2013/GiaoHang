import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Content-Type': 'application/json',
};

// Chỉ ba thông tin liên hệ công khai; không phụ thuộc phiên đăng nhập hoặc trạng thái tài khoản.
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (!['GET', 'POST'].includes(request.method)) {
    return new Response(JSON.stringify({error:'METHOD_NOT_ALLOWED'}), {status:405, headers});
  }
  const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    {auth:{persistSession:false}});
  const {data,error} = await client.rpc('get_business_contact');
  if (error || !data) {
    return new Response(JSON.stringify({error:'CONTACT_UNAVAILABLE'}), {status:503, headers});
  }
  return new Response(JSON.stringify({
    company_name:data.company_name, support_phone:data.support_phone, support_email:data.support_email,
  }), {headers});
});
