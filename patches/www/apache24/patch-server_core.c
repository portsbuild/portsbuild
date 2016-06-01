--- server/core.c.orig  2016-06-01 16:04:41 UTC
+++ server/core.c
@@ -139,7 +139,7 @@ static void *create_core_dir_config(apr_
     conf->opts = dir ? OPT_UNSET : OPT_UNSET|OPT_SYM_LINKS;
     conf->opts_add = conf->opts_remove = OPT_NONE;
     conf->override = OR_UNSET|OR_NONE;
-    conf->override_opts = OPT_UNSET | OPT_ALL | OPT_SYM_OWNER | OPT_MULTI;
+    conf->override_opts = OPT_UNSET | OPT_ALL | OPT_SYM_LINKS | OPT_MULTI;

     conf->content_md5 = AP_CONTENT_MD5_UNSET;
     conf->accept_path_info = AP_ACCEPT_PATHINFO_UNSET;
@@ -1683,11 +1683,15 @@ static const char *set_allow_opts(cmd_pa
             opt = OPT_INCLUDES;
         }
         else if (!strcasecmp(w, "FollowSymLinks")) {
-            opt = OPT_SYM_LINKS;
+            opt = OPT_SYM_OWNER;
         }
+        /* XXX COMPAT */
         else if (!strcasecmp(w, "SymLinksIfOwnerMatch")) {
             opt = OPT_SYM_OWNER;
         }
+        else if (!strcasecmp(w, "UnhardenedSymLinks")) {
+             opt = OPT_SYM_LINKS;
+        }
         else if (!strcasecmp(w, "ExecCGI")) {
             opt = OPT_EXECCGI;
         }
@@ -1897,11 +1901,15 @@ static const char *set_options(cmd_parms
             opt = OPT_INCLUDES;
         }
         else if (!strcasecmp(w, "FollowSymLinks")) {
-            opt = OPT_SYM_LINKS;
+            opt = OPT_SYM_OWNER;
         }
+        /* XXX COMPAT */
         else if (!strcasecmp(w, "SymLinksIfOwnerMatch")) {
             opt = OPT_SYM_OWNER;
         }
+        else if (!strcasecmp(w, "UnhardenedSymLinks")) {
+            opt = OPT_SYM_LINKS;
+        }
         else if (!strcasecmp(w, "ExecCGI")) {
             opt = OPT_EXECCGI;
         }
