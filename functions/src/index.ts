import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";

// تهيئة تطبيق Firebase Admin للتحكم بقاعدة البيانات والإشعارات
// admin.initializeApp(); // Assuming this is already called elsewhere or at the top of your actual file if you combine them. I will leave it here as it was in your snippet, but ensure it's only called once globally.
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();

// دالة مساعدة لحساب المسافة التقريبية بين نقطتين (Haversine formula)
function getDistanceFromLatLonInKm(lat1: number, lon1: number, lat2: number, lon2: number) {
    const R = 6371; // نصف قطر الأرض بالكيلومتر
    const dLat = (lat2 - lat1) * (Math.PI / 180);
    const dLon = (lon2 - lon1) * (Math.PI / 180);
    const a = 
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) * 
        Math.sin(dLon / 2) * Math.sin(dLon / 2); 
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)); 
    return R * c; // المسافة بالكيلومتر
}

// ----------------------------------------------------------------------
// 1. وظيفة جلب البيانات البيئية (مثال: بيانات الزلازل من USGS)
// ----------------------------------------------------------------------
export const fetchUSGSEarthquakes = functions.pubsub.schedule("every 60 minutes").onRun(async (context: functions.EventContext) => {
    try {
        // رابط API للزلازل التي قوتها أكبر من 4.5 خلال اليوم الماضي
        // تنفيذ عملية الحفظ الجماعي
        await batch.commit();
        console.log(`Successfully processed and saved ${features.length} earthquake records.`);
        return null;

    } catch (error) {
        console.error("Error fetching data from USGS:", error);
        return null;
    }
});

// ----------------------------------------------------------------------
// 2. وظيفة إرسال الإشعارات اللحظية عند رصد خطر جديد
// ----------------------------------------------------------------------
export const sendHazardNotification = functions.firestore
    .document("environmental_hazards/{hazardId}")
    .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
        const newHazard = snap.data();
        try {
            // إرسال الإشعار لجميع المشتركين في موضوع 'all_alerts'
            const response = await admin.messaging().send(message);
            console.log("Notification sent successfully:", response);
            return null;
        } catch (error) {
            console.error("Error sending notification:", error);
            return null;
        }
    });

// ----------------------------------------------------------------------
// 3. خوارزمية التوثيق التلقائي للبلاغات المجتمعية (Automated Verification)
// تراقب البلاغات الجديدة، وإذا وجدنا 3 بلاغات متقاربة يتم تحويلها لخطر رسمي
// ----------------------------------------------------------------------
export const verifyCommunityReport = functions.firestore
    .document("community_reports/{reportId}")
    .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
        const newReport = snap.data();
        
        // إذا كان البلاغ ليس في حالة الانتظار، نتخطاه
        if (newReport.status !== 'pending_verification') return null;

        const reportLat = newReport.coordinates.latitude;
        const reportLng = newReport.coordinates.longitude;
        const hazardType = newReport.type;
        const severity = newReport.severity;

        // 1. تحديد الزمن (نبحث عن البلاغات خلال آخر ساعتين فقط لضمان أنها نفس الحدث)
        const twoHoursAgo = new Date();
        twoHoursAgo.setHours(twoHoursAgo.getHours() - 2);

        try {
            // جلب البلاغات المشابهة زمنياً ومن نفس النوع
            const similarReportsSnapshot = await db.collection("community_reports")
                .where("type", "==", hazardType)
                .where("status", "==", "pending_verification")
                .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(twoHoursAgo))
                .get();

            let nearbyReportsCount = 0;
            const reportsToVerify: string[] = [];

            // 2. تصفية البلاغات مكانياً (Clustering - نبحث ضمن دائرة قطرها 5 كيلومتر)
            similarReportsSnapshot.forEach((doc) => {
                const data = doc.data();
                // تأكد من وجود الإحداثيات في البلاغ القديم
                if (data.coordinates && data.coordinates.latitude && data.coordinates.longitude) {
                     const distance = getDistanceFromLatLonInKm(
                        reportLat, reportLng, 
                        data.coordinates.latitude, data.coordinates.longitude
                    );

                    // إذا كان البلاغ ضمن النطاق الجغرافي (5 كيلومتر)
                    if (distance <= 5.0) { 
                        nearbyReportsCount++;
                        reportsToVerify.push(doc.id);
                    }
                }
            });

            // 3. التحقق (Threshold): إذا وجدنا 3 بلاغات قريبة أو أكثر (بما فيها البلاغ الحالي)
            if (nearbyReportsCount >= 3) {
                console.log(`[VERIFIED] ${hazardType} hazard crossed threshold! Count: ${nearbyReportsCount}`);

                const batch = db.batch();

                // أ. تغيير حالة جميع البلاغات المتقاطعة إلى "تم التحقق منها" حتى لا يتم احتسابها مرة أخرى
                reportsToVerify.forEach(id => {
                    const ref = db.collection("community_reports").doc(id);
                    batch.update(ref, { status: 'verified' });
                });

                // ب. إنشاء تنبيه رسمي في لوحة القيادة لجميع المستخدمين
                // بمجرد إضافة هذا المستند، ستعمل دالة sendHazardNotification تلقائياً!
                const officialHazardRef = db.collection("environmental_hazards").doc();
                batch.set(officialHazardRef, {
                    title: `تحذير مجتمعي موثّق: ${hazardType}`,
                    type: hazardType,
                    severity: severity, // نعتمد شدة البلاغ الأخير
                    location_name: "موقع تم الإبلاغ عنه من قبل السكان",
                    coordinates: {
                        latitude: reportLat,
                        longitude: reportLng,
                    },
                    timestamp: admin.firestore.FieldValue.serverTimestamp(),
                    source: 'Eco Alert Community (Verified)',
                    details: `تم توثيق هذا الخطر تلقائياً بناءً على تقاطع ${nearbyReportsCount} بلاغات محلية مستقلة.`
                });

                // تنفيذ العمليات دفعة واحدة (Transaction-like)
                await batch.commit();
                
            } else {
                console.log(`[PENDING] Not enough reports yet for ${hazardType}. Current count in area: ${nearbyReportsCount}/3`);
            }

            return null;
        } catch (error) {
            console.error("Error in verification algorithm:", error);
            return null;
        }
    });