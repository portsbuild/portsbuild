--- include/http_core.h.orig    2016-06-01 16:04:15 UTC
+++ include/http_core.h
@@ -84,7 +84,7 @@ extern "C" {
 /** MultiViews directive */
 #define OPT_MULTI 128
 /**  All directives */
-#define OPT_ALL (OPT_INDEXES|OPT_INCLUDES|OPT_INC_WITH_EXEC|OPT_SYM_LINKS|OPT_EXECCGI)
+#define OPT_ALL (OPT_INDEXES|OPT_INCLUDES|OPT_INC_WITH_EXEC|OPT_SYM_OWNER|OPT_EXECCGI)
 /** @} */

 /**
