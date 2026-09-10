module("luci.controller.tiktok_acl", package.seeall)
function index()
  entry({"admin","network","tiktok_acl"}, call("page"), _("TikTok WiFi ACL"), 80).dependent=false
end
function page()
  local http=require "luci.http"; local uci=require "luci.model.uci".cursor()
  if http.formvalue("apply") then
    for i=1,10 do local n="tk"..i; uci:set("tiktok_acl",n,"policy",http.formvalue("policy"..i) or "global") end
    uci:commit("tiktok_acl"); http.redirect("/cgi-bin/luci/admin/network/tiktok_acl")
  end
  luci.template.render("tiktok_acl",{uci=uci})
end
