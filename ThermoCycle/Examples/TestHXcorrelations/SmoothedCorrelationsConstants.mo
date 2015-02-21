within ThermoCycle.Examples.TestHXcorrelations;
model SmoothedCorrelationsConstants
  extends Test_HeatTransferTester(tester(redeclare model HeatTransfer =
          ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.SmoothedInit
          (
          filterConstant=0,
          max_dUdt=0,
          redeclare model LiquidCorrelation =
              ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.SinglePhaseCorrelations.Constant
              (U_c=tester.U_nom_l),
          redeclare model TwoPhaseCorrelation =
              ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.TwoPhaseCorrelations.Constant
              (U_c=tester.U_nom_tp),
          redeclare model VapourCorrelation =
              ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.SinglePhaseCorrelations.Constant
              (U_c=tester.U_nom_v),
          t_start=Modelica.Constants.small,
          t_init=Modelica.Constants.small)));
end SmoothedCorrelationsConstants;
