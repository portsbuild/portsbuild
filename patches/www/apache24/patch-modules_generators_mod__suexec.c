--- modules/generators/mod_suexec.c.orig        2016-06-01 14:25:43 UTC
+++ modules/generators/mod_suexec.c
@@ -59,7 +59,7 @@ static const char *set_suexec_ugid(cmd_p
                                    const char *uid, const char *gid)
 {
     suexec_config_t *cfg = (suexec_config_t *) mconfig;
-    const char *err = ap_check_cmd_context(cmd, NOT_IN_DIR_LOC_FILE);
+    const char *err = ap_check_cmd_context(cmd, NOT_IN_LOCATION|NOT_IN_FILES);

     if (err != NULL) {
         return err;
@@ -116,7 +116,7 @@ static const command_rec suexec_cmds[] =
 {
     /* XXX - Another important reason not to allow this in .htaccess is that
      * the ap_[ug]name2id() is not thread-safe */
-    AP_INIT_TAKE2("SuexecUserGroup", set_suexec_ugid, NULL, RSRC_CONF,
+    AP_INIT_TAKE2("SuexecUserGroup", set_suexec_ugid, NULL, RSRC_CONF|ACCESS_CONF,
       "User and group for spawned processes"),
     { NULL }
 };
