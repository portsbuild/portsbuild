--- dbm/sdbm/sdbm_private.h.orig    2014-12-15 17:57:23.592996229 -0700
+++ dbm/sdbm/sdbm_private.h 2014-12-15 17:58:11.127996437 -0700
@@ -34,9 +34,9 @@
 #define PBLKSIZ 8192
 #define PAIRMAX 8008           /* arbitrary on PBLKSIZ-N */
 #else
-#define DBLKSIZ 4096
-#define PBLKSIZ 1024
-#define PAIRMAX 1008           /* arbitrary on PBLKSIZ-N */
+#define DBLKSIZ 16384
+#define PBLKSIZ 8192
+#define PAIRMAX 10080          /* arbitrary on PBLKSIZ-N */
 #endif
 #define SPLTMAX    10          /* maximum allowed splits */
