// Fyzikální konstanty — neměň bez komentáře proč.
const double kRingMass = 1.0;
const double kRingRadius = 44.0;
const double kDrag = 0.018;
const double kElasticity = 0.72;
const double kWallFriction = 0.86;
const double kStiffness = 180.0;
const double kContactZone = 1.6; // násobek radius
const double kFlickThreshold = 300.0; // px/s
const double kFlickScale = 0.008;
const double kSyncInterval = 2.0; // sekundy mezi ring_hint
const double kSyncLerp = 0.12;

// Vodní hladina / odraz obličeje
const double kFaceUpdateInterval = 9.0; // sekundy mezi snímky z kamery
const int kMaxRipples = 12; // musí odpovídat uRipples[12] ve water.frag
const double kRippleMaxAge = 2.5; // sekundy, pak vlnka mizí
const double kRippleMinSpawnGap = 0.05; // sekundy mezi spawny při tažení
