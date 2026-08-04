require("ts-node/register/transpile-only");
const { expect } = require("chai");

const {
  createOperationalZoneSchema,
  updateOperationalZoneSchema,
} = require("../../src/modules/operational-zone/operational-zone.validation");

describe("operational-zone.validation schemas", () => {
  it("createOperationalZoneSchema enforces closed polygon", () => {
    const openCoords = {
      zone_name: "Z1",
      coordinates: [
        [0, 0],
        [1, 0],
        [1, 1],
      ],
    };

    const open = createOperationalZoneSchema.safeParse({
      body: openCoords,
      params: {},
      query: {},
    });
    expect(open.success).to.equal(false);

    const closedCoords = {
      zone_name: "Z1",
      coordinates: [
        [0, 0],
        [1, 0],
        [0, 0],
      ],
    };

    const closed = createOperationalZoneSchema.safeParse({
      body: closedCoords,
      params: {},
      query: {},
    });
    expect(closed.success).to.equal(true);
  });

  it("updateOperationalZoneSchema refine requires at least one field", () => {
    const none = updateOperationalZoneSchema.safeParse({
      body: {},
      params: { id: "1" },
      query: {},
    });
    expect(none.success).to.equal(false);

    const onlyName = updateOperationalZoneSchema.safeParse({
      body: { zone_name: "Z2" },
      params: { id: "1" },
      query: {},
    });
    expect(onlyName.success).to.equal(true);
  });
});

