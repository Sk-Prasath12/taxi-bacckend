require("ts-node/register/transpile-only");
const { expect } = require("chai");
const { calculateCommission } = require("../../src/modules/common/commission.service");

describe("commission.service", () => {
  it("returns zero values for invalid amount", () => {
    expect(calculateCommission(0)).to.deep.equal({ commission: 0, driverAmount: 0 });
    expect(calculateCommission(-1)).to.deep.equal({ commission: 0, driverAmount: 0 });
    expect(calculateCommission(null)).to.deep.equal({ commission: 0, driverAmount: 0 });
  });

  it("calculates rounded commission for normal amount", () => {
    expect(calculateCommission(100)).to.deep.equal({ commission: 20, driverAmount: 80 });
  });

  it("calculates boundary floating amount", () => {
    expect(calculateCommission(99.5)).to.deep.equal({ commission: 20, driverAmount: 80 });
  });
});
