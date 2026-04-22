double CalculateLot(double riskPercent, double stopDistance)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = balance * (riskPercent / 100.0);

   double lot = risk / stopDistance;
   return NormalizeDouble(lot, 2);
}