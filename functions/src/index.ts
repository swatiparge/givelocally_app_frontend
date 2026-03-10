import * as functions from "firebase-functions";
import {verifyPickupCode} from "./verifyPickupCode";

// Export all Cloud Functions
export {verifyPickupCode};

// Optional: Default export for testing
export default {
  verifyPickupCode,
};
