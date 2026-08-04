export const calculateCommission = (amount: number) => {
  if (!amount || amount <= 0) {
    return {
      commission: 0,
      driverAmount: 0,
    };
  }

  const COMMISSION_RATE = 0.2; // 20%

  const commission = Math.round(amount * COMMISSION_RATE);
  const driverAmount = Math.round(amount - commission);

  return {
    commission,
    driverAmount,
  };
};
