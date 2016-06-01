--- support/suexec.c.orig       2016-06-01 14:27:32 UTC
+++ support/suexec.c
@@ -309,6 +309,7 @@ int main(int argc, char *argv[])
 #ifdef AP_SUEXEC_UMASK
         fprintf(stderr, " -D AP_SUEXEC_UMASK=%03o\n", AP_SUEXEC_UMASK);
 #endif
+        fprintf(stderr, " -D AP_PER_DIR=\"yes\"\n");
 #ifdef AP_UID_MIN
         fprintf(stderr, " -D AP_UID_MIN=%d\n", AP_UID_MIN);
 #endif
