const Notification = require("../models/Notification");

const getCustomerNotifications = async (req, res) => {
  const notifications = await Notification.find({
    userType: "customer",
    userId: req.customer._id.toString()
  }).sort({ createdAt: -1 });
  return res.json({ success: true, data: notifications });
};

module.exports = {
  getCustomerNotifications
};
