require("ts-node/register/transpile-only");
const { expect } = require("chai");

const zoneValidation = require("../../src/modules/operational-zone/operational-zone.validation");
const usersValidation = require("../../src/modules/users/users.validation");
const docValidation = require("../../src/modules/driver-documents/driver-document.validation");
const { getDriverUploadedFile } = require("../../src/modules/driver-documents/driver-document.upload");

describe("validation schemas", () => {
  it("operational zone schemas parse and reject invalid polygon", () => {
    const good = zoneValidation.createOperationalZoneSchema.parse({
      body: { zone_name: "A", coordinates: [[1, 1], [2, 2], [1, 1]] },
      params: {},
      query: {},
    });
    expect(good.body.zone_name).to.equal("A");

    expect(() =>
      zoneValidation.createOperationalZoneSchema.parse({
        body: { zone_name: "A", coordinates: [[1, 1], [2, 2], [3, 3]] },
        params: {},
        query: {},
      })
    ).to.throw();
  });

  it("user and document schemas parse expected fields", () => {
    const user = usersValidation.createUserSchema.parse({
      body: { name: "John", email: "john@example.com", password: "12345678" },
      params: {},
      query: {},
    });
    expect(user.body.email).to.equal("john@example.com");

    const parsed = docValidation.adminDocumentStatusSchema.parse({
      body: { status: "APPROVED" },
      params: { id: "507f1f77bcf86cd799439011" },
      query: {},
    });
    expect(parsed.body.status).to.equal("APPROVED");
    expect(() =>
      docValidation.adminDocumentStatusSchema.parse({
        body: { status: "REJECTED" },
        params: { id: "507f1f77bcf86cd799439011" },
        query: {},
      })
    ).to.throw();
  });

  it("driver upload helper returns matching file by precedence", () => {
    const req = { files: { document: [{ originalname: "a.png" }] } };
    const file = getDriverUploadedFile(req);
    expect(file.originalname).to.equal("a.png");
    expect(getDriverUploadedFile({})).to.equal(undefined);
  });
});
