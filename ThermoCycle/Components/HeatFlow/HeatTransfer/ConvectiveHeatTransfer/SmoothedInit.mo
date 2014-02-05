within ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer;
model SmoothedInit
  "SmoothedInit: Smooth transitions between the different flow regimes including an initialisation and a filtering"
  extends BaseClasses.PartialConvectiveSmoothed(
  redeclare replaceable package Medium =
        Modelica.Media.Interfaces.PartialTwoPhaseMedium
  constrainedby Modelica.Media.Interfaces.PartialTwoPhaseMedium);

  parameter Modelica.SIunits.Time t_start=5 "Start of initialization"
    annotation(Dialog(tab="Initialization"));
  parameter Modelica.SIunits.Time t_init=5 "Duration of initialization"
    annotation(Dialog(tab="Initialization"));

  parameter Modelica.SIunits.Time filterConstant = 0
    "Integration time of filter, 0=disabled"
                               annotation(Dialog(group="Correlations"));

  parameter Real max_dUdt(unit="W/(m2.K.s)") = 10000
    "maximum change in HTC, 0=disabled"
                             annotation(Dialog(group="Correlations"),enabled=(filterConstant>0));
  Real dUdt_limiter;
  Modelica.SIunits.CoefficientOfHeatTransfer U_limited;
  Modelica.SIunits.CoefficientOfHeatTransfer U_filtered;
  Modelica.SIunits.CoefficientOfHeatTransfer U_initialized;
  Real initialized(min=0,max=1);

  Modelica.SIunits.CoefficientOfHeatTransfer U_cor_l;
  Modelica.SIunits.CoefficientOfHeatTransfer U_cor_tp;
  Modelica.SIunits.CoefficientOfHeatTransfer U_cor_v;

  replaceable model LiquidCorrelation =
    ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.BaseClasses.PartialSinglePhaseCorrelation
  constrainedby
    ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.BaseClasses.PartialSinglePhaseCorrelation
    "correlated heat transfer coefficient liquid side"
                                                     annotation(Dialog(group="Correlations"),choicesAllMatching=true);

   replaceable model TwoPhaseCorrelation =
     ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.BaseClasses.PartialTwoPhaseCorrelation
   constrainedby
    ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.BaseClasses.PartialTwoPhaseCorrelation
    "correlated heat transfer coefficient two phase side"
                                                      annotation(Dialog(group="Correlations"),choicesAllMatching=true);

  replaceable model VapourCorrelation =
    ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.BaseClasses.PartialSinglePhaseCorrelation
     constrainedby
    ThermoCycle.Components.HeatFlow.HeatTransfer.ConvectiveHeatTransfer.BaseClasses.PartialSinglePhaseCorrelation
    "correlated heat transfer coefficient vapour side" annotation (Dialog(group=
         "Correlations"), choicesAllMatching=true);

  LiquidCorrelation   liquidCorrelation(  redeclare final package Medium = Medium, state = state_L,  m_dot = M_dot, q_dot = q_dot[1]);
  TwoPhaseCorrelation twoPhaseCorrelation(redeclare final package Medium = Medium, state = state_TP, m_dot = M_dot, q_dot = q_dot[1]);
  VapourCorrelation   vapourCorrelation(  redeclare final package Medium = Medium, state = state_V,  m_dot = M_dot, q_dot = q_dot[1]);

  Modelica.SIunits.CoefficientOfHeatTransfer    U_cor_LTP;
  Modelica.SIunits.CoefficientOfHeatTransfer    U_cor_TPV;
  Modelica.SIunits.CoefficientOfHeatTransfer    U_cor;

  //Define filtered states to avoid spikes at phase boundary
  Medium.ThermodynamicState state;
  Medium.ThermodynamicState state_L;
  Medium.ThermodynamicState state_TP;
  Medium.ThermodynamicState state_V "the different states";

  Medium.SpecificEnthalpy h_bub_TP;
  Medium.SpecificEnthalpy h_dew_TP;
  Medium.SpecificEnthalpy h_bub_L;
  Medium.SpecificEnthalpy h_dew_V;
  Medium.SpecificEnthalpy delta_h;
  Medium.SpecificEnthalpy h_bub;
  Medium.SpecificEnthalpy h_dew "Changed bubble and dew state enthalpies";
  Medium.AbsolutePressure p;
  Medium.SpecificEnthalpy h;
  Medium.SpecificEnthalpy h_L;
  Medium.SpecificEnthalpy h_V;
  Medium.SpecificEnthalpy h_TP;

initial algorithm
  U_filtered := U_nom;
  U_limited  := U_filtered;

equation
  state    = FluidState[1];
  p        = Medium.pressure(state);
  h        = Medium.specificEnthalpy(state);

  h_bub    = Medium.bubbleEnthalpy(Medium.setSat_p(p));
  h_dew    = Medium.dewEnthalpy(   Medium.setSat_p(p));
  delta_h  = h_dew-h_bub;

  h_bub_L  = h_bub + x_L  *delta_h;
  h_bub_TP = h_bub + x_LTP*delta_h;
  h_dew_TP = h_bub + x_TPV*delta_h;
  h_dew_V  = h_bub + x_V  *delta_h;

  h_L      = min(h,h_bub_L);
  h_TP     = max(h_bub_TP,min(h_dew_TP, h));
  h_V      = max(h,h_dew_V);

  state_L  = Medium.setState_phX(p=p,h=h_L);
  state_TP = Medium.setState_phX(p=p,h=h_TP);
  state_V  = Medium.setState_phX(p=p,h=h_V);

  U_cor_l  = liquidCorrelation.U;
  U_cor_tp = twoPhaseCorrelation.U;
  U_cor_v  = vapourCorrelation.U;

  U_cor_LTP = (1-LTP)*U_cor_l + LTP*U_cor_tp;
  U_cor_TPV = (1-TPV)*U_cor_tp + TPV*U_cor_v;
  U_cor     = (1-LV) *U_cor_LTP+ LV* U_cor_TPV;

  initialized     = ThermoCycle.Functions.transition_factor(start=t_start, stop=t_start+t_init, position=time);
  U_initialized   = (1-initialized)*U_nom*massFlowFactor + initialized*U_cor;

   if filterConstant<=0 then
     //U_filtered = U_initialized;
     der(U_filtered) = (U_initialized-U_filtered)/1e-8;
   else
     der(U_filtered) = (U_initialized-U_filtered)/filterConstant;
   end if;

   if max_dUdt<=0 then
     dUdt_limiter = 0;
     der(U_limited) = der(U_filtered);//(U_filtered-U_limited)/1e-8;
   else
     dUdt_limiter = (ThermoCycle.Functions.transition_factor(start=-max_dUdt, stop=max_dUdt, position=(U_filtered-U_limited)/1e-5)-0.5)*2;
     der(U_limited) = dUdt_limiter*max_dUdt;
   end if;

  for i in 1:n loop
    U[i] = U_limited;
  end for;
end SmoothedInit;
