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
@@ -314,6 +314,9 @@ int main(int argc, char *argv[])
 #ifdef AP_USERDIR_SUFFIX
         fprintf(stderr, " -D AP_USERDIR_SUFFIX=\"%s\"\n", AP_USERDIR_SUFFIX);
 #endif
+#ifdef AP_SAFE_DIRECTORY
+        fprintf(stderr, " -D AP_SAFE_DIRECTORY=\"%s\"\n", AP_SAFE_DIRECTORY);
+#endif
         exit(0);
     }
     /*
@@ -497,11 +500,32 @@ int main(int argc, char *argv[])
      * Use chdir()s and getcwd()s to avoid problems with symlinked
      * directories.  Yuck.
      */
+
     if (getcwd(cwd, AP_MAXPATH) == NULL) {
         log_err("cannot get current working directory\n");
         exit(111);
     }

+    /* Check for safe directory existence */
+#ifdef AP_SAFE_DIRECTORY
+    char safe_dr[AP_MAXPATH];
+    int is_safe_dir_present = 0;
+    struct stat safe_dir_info;
+    if (((lstat(AP_SAFE_DIRECTORY, &safe_dir_info)) == 0) && (S_ISDIR(safe_dir_info.st_mode))) {
+       is_safe_dir_present = 1;
+    }
+
+    if(is_safe_dir_present){
+       if (((chdir(AP_SAFE_DIRECTORY)) != 0) ||
+           ((getcwd(safe_dr, AP_MAXPATH)) == NULL) ||
+           ((chdir(cwd)) != 0)) {
+           log_err("cannot get safe directory information (%s)\n", AP_SAFE_DIRECTORY);
+           exit(200);
+       }
+    }
+#endif
+
+
     if (userdir) {
         if (((chdir(target_homedir)) != 0) ||
             ((chdir(AP_USERDIR_SUFFIX)) != 0) ||
@@ -520,10 +544,28 @@ int main(int argc, char *argv[])
         }
     }

-    if ((strncmp(cwd, dwd, strlen(dwd))) != 0) {
-        log_err("command not in docroot (%s/%s)\n", cwd, cmd);
-        exit(114);
+#ifdef AP_SAFE_DIRECTORY
+    int safe_work = 0;
+    if(is_safe_dir_present){
+       if ((strncmp(cwd, safe_dr, strlen(safe_dr))) != 0){
+           if ((strncmp(cwd, dwd, strlen(dwd))) != 0) {
+             log_err("command not in docroot (%s/%s)\n", cwd, cmd);
+             exit(114);
+           }
+       } else {
+           safe_work = 1;
+       }
+    } else {
+#endif
+       if ((strncmp(cwd, dwd, strlen(dwd))) != 0) {
+         log_err("command not in docroot (%s/%s)\n", cwd, cmd);
+         exit(114);
+       }
+#ifdef AP_SAFE_DIRECTORY
     }
+#endif
+
+

     /*
      * Stat the cwd and verify it is a directory, or error out.
@@ -569,6 +611,9 @@ int main(int argc, char *argv[])
      * Error out if the target name/group is different from
      * the name/group of the cwd or the program.
      */
+#ifdef AP_SAFE_DIRECTORY
+    if (!safe_work){
+#endif
     if ((uid != dir_info.st_uid) ||
         (gid != dir_info.st_gid) ||
         (uid != prg_info.st_uid) ||
@@ -580,6 +625,9 @@ int main(int argc, char *argv[])
                 (unsigned long)prg_info.st_uid, (unsigned long)prg_info.st_gid);
         exit(120);
     }
+#ifdef AP_SAFE_DIRECTORY
+    }
+#endif
     /*
      * Error out if the program is not executable for the user.
      * Otherwise, she won't find any error in the logs except for
