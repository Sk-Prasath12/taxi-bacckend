require("ts-node/register/transpile-only");
const { expect } = require("chai");

const { upsertDriverProfileBodySchema } = require("../../src/modules/driver-profile/driver-profile.validation");

describe("driver-profile.validation schemas", () => {
  it("accepts empty strings (transformed to undefined) for optional fields", () => {
    const out = upsertDriverProfileBodySchema.safeParse({
      phone: "",
      ifsc_code: "",
      aadhaar_number: "",
      pan_number: "",
      vehicle_type_id: "",
      dob: "",
      address: "",
    });
    expect(out.success).to.equal(true);
  });

  it("validates optional phone/ifsc/aadhaar/pan/objectId refinements", () => {
    const badPhone = upsertDriverProfileBodySchema.safeParse({
      phone: "123",
    });
    expect(badPhone.success).to.equal(false);

    const goodPhone = upsertDriverProfileBodySchema.safeParse({
      phone: "+91 98765 43210",
    });
    expect(goodPhone.success).to.equal(true);

    const badIfsc = upsertDriverProfileBodySchema.safeParse({
      ifsc_code: "SBIN000123",
    });
    expect(badIfsc.success).to.equal(false);

    const badAadhaar = upsertDriverProfileBodySchema.safeParse({
      aadhaar_number: "1234567890",
    });
    expect(badAadhaar.success).to.equal(false);

    const badPan = upsertDriverProfileBodySchema.safeParse({
      pan_number: "ABCDE1234",
    });
    expect(badPan.success).to.equal(false);

    const badObjectId = upsertDriverProfileBodySchema.safeParse({
      vehicle_type_id: "not-an-objectid",
    });
    expect(badObjectId.success).to.equal(false);
  });

  it("preprocesses optional dob values", () => {
    const okEmpty = upsertDriverProfileBodySchema.safeParse({ dob: "" });
    expect(okEmpty.success).to.equal(true);

    const okDate = upsertDriverProfileBodySchema.safeParse({ dob: "2020-01-01" });
    expect(okDate.success).to.equal(true);
    expect(okDate.data.dob).to.be.instanceOf(Date);
  });
});

