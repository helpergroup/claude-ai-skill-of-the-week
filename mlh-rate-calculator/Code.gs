/**
 * MLH Rate Calculator — Web App Endpoint (doGet)
 * =================================================================
 * Single read-only JSON endpoint over the existing "New Rate Calculator"
 * Google Sheet. Serves BOTH the GHL agent quoting flow and the Dispatch
 * Helper bridge (Netlify).
 *
 * HARD RULES (do not relax):
 *   1. The sheet's own formulas are NEVER touched.
 *   2. This endpoint READS the per-tab rate constants; it never writes to
 *      the sheet.
 *   3. It returns JSON only — no HTML, no logging text in the body.
 *   4. The office origin is LOCKED to Charlotte, NC 28273.
 *
 * It reproduces the math the sheet runs: GOOGLEMAPS mileage (Office->Pickup
 * deadhead miles, Pickup->Dropoff billable miles) is recreated with the
 * Apps Script Maps service, and the per-tab rates drive the fee total.
 * Rates are read live from the selected tab, so nothing is hard-coded or
 * invented — change a rate in the sheet and the endpoint follows.
 *
 * URL params (doGet):
 *   pickup          pickup address (required)
 *   dropoff         drop-off address (required)
 *   accountType     selects the rate tab (see ACCOUNT_TABS) (required)
 *   passengers      total passenger count (default 1)
 *   waitTimeHours   billable wait, in hours (default 0)
 *   roundTrip       true/false (default false)
 *   jobId           pass-through id, echoed back (optional)
 *
 * Returns: { jobId, accountType, miles, timeEstimate, totalFare }
 */

// ====================================================================
// CONFIG — verify these against the live sheet before publishing.
// ====================================================================

/** The Rate Calculator spreadsheet id (from the sheet URL). */
var SPREADSHEET_ID = '1LqxRrzz6Qa3CUSwXtdYuNdQu_pFGFyZHN-BpKVwknMM';

/** Locked office origin. Charlotte, NC 28273 — never overridden by a param. */
var OFFICE_ORIGIN = 'Charlotte, NC 28273';

/**
 * accountType (as sent in the URL) -> exact tab/sheet name in the workbook.
 * Keys are matched case-insensitively. If a tab is named differently in the
 * workbook, fix the value on the right — the endpoint reads getSheetByName().
 */
var ACCOUNT_TABS = {
  'master':           'Master',
  'sono bello':       'Sono Bello',
  'private pay':      'Private Pay',
  'student reduced':  'Student Reduced',
  'student standard': 'Student Standard',
  'wheelchair':       'Wheelchair'
  // Add broker tabs here, e.g.:
  // 'modivcare':     'ModivCare',
  // 'veyo':          'Veyo'
};

/**
 * Account types that carry a flat Base fare (per Melessa: Private Pay and
 * out-of-area broker trips). Matched case-insensitively. Add each broker
 * accountType here so its Base ($) is included; all other tabs ignore Base.
 */
var BASE_FARE_ACCOUNTS = [
  'private pay'
  // , 'modivcare', 'veyo'   // <- add broker accountTypes here
];

/** First passenger is included; surcharge applies to each one beyond this. */
var INCLUDED_PASSENGERS = 1;

// ====================================================================
// ENDPOINT
// ====================================================================

function doGet(e) {
  var params = (e && e.parameter) ? e.parameter : {};
  var jobId = params.jobId || null;

  try {
    // ---- inputs -------------------------------------------------------
    var pickup = trimOrNull_(params.pickup);
    var dropoff = trimOrNull_(params.dropoff);
    var accountTypeRaw = trimOrNull_(params.accountType);
    var passengers = toNumber_(params.passengers, 1);
    var waitTimeHours = toNumber_(params.waitTimeHours, 0);
    var roundTrip = toBool_(params.roundTrip);

    if (!pickup || !dropoff || !accountTypeRaw) {
      return json_({
        jobId: jobId,
        error: 'Missing required parameter(s). Required: pickup, dropoff, accountType.'
      });
    }

    // ---- resolve rate tab --------------------------------------------
    var key = accountTypeRaw.toLowerCase();
    var tabName = ACCOUNT_TABS[key];
    if (!tabName) {
      return json_({
        jobId: jobId,
        error: 'Unknown accountType "' + accountTypeRaw + '". Valid: ' +
               Object.keys(ACCOUNT_TABS).join(', ')
      });
    }

    var sheet = SpreadsheetApp.openById(SPREADSHEET_ID).getSheetByName(tabName);
    if (!sheet) {
      return json_({ jobId: jobId, error: 'Rate tab not found: "' + tabName + '".' });
    }

    // ---- read per-tab rates (read-only) ------------------------------
    var values = sheet.getDataRange().getValues();
    var rates = {
      perMile:  readRate_(values, function (l) { return l === 'per mile'; }),
      base:     readRate_(values, function (l) { return l === 'base'; }),
      addlPax:  readRate_(values, function (l) { return l.indexOf('additional passenger') === 0; }),
      wait:     readRate_(values, function (l) { return l.indexOf('wait time') === 0; }),
      deadhead: readRate_(values, function (l) { return l === 'deadhead miles'; })
    };

    if (rates.perMile == null) {
      return json_({ jobId: jobId, error: 'Could not read "Per Mile" rate on tab "' + tabName + '".' });
    }

    // ---- mileage + time via Maps (reproduces GOOGLEMAPS) -------------
    var billableLeg = drive_(pickup, dropoff);   // Pickup -> Dropoff
    var deadheadLeg = drive_(OFFICE_ORIGIN, pickup); // Office -> Pickup

    if (!billableLeg) {
      return json_({ jobId: jobId, error: 'No route found Pickup -> Dropoff. Check the addresses.' });
    }
    if (!deadheadLeg) {
      return json_({ jobId: jobId, error: 'No route found Office -> Pickup. Check the pickup address.' });
    }

    var tripMultiplier = roundTrip ? 2 : 1;
    var billableMiles = round1_(billableLeg.miles) * tripMultiplier;
    var deadheadMiles = round1_(deadheadLeg.miles) * tripMultiplier;
    var driveMinutes = Math.round(billableLeg.minutes) * tripMultiplier;

    // ---- fees (the exact math the sheet runs) ------------------------
    var milesFee = billableMiles * (rates.perMile || 0);
    var deadheadFee = deadheadMiles * (rates.deadhead || 0);
    var addlPaxFee = Math.max(0, passengers - INCLUDED_PASSENGERS) * (rates.addlPax || 0);
    var waitFee = waitTimeHours * (rates.wait || 0);
    var baseFee = accountHasBase_(key) ? (rates.base || 0) : 0;

    var totalFare = milesFee + deadheadFee + addlPaxFee + waitFee + baseFee;

    // ---- response ----------------------------------------------------
    return json_({
      jobId: jobId,
      accountType: tabName,
      miles: round1_(billableMiles),
      timeEstimate: formatDuration_(driveMinutes),
      totalFare: round2_(totalFare)
    });

  } catch (err) {
    return json_({ jobId: jobId, error: 'Quote failed: ' + err.message });
  }
}

// ====================================================================
// HELPERS
// ====================================================================

/** Scan the value grid for the first row whose label matches, return the
 *  first numeric cell to its right. The rate block sits above the fee block,
 *  so the first match is always the rate constant. Returns null if absent. */
function readRate_(values, labelMatches) {
  for (var r = 0; r < values.length; r++) {
    var row = values[r];
    for (var c = 0; c < row.length; c++) {
      var label = String(row[c] == null ? '' : row[c]).trim().toLowerCase();
      if (label && labelMatches(label)) {
        for (var k = c + 1; k < row.length; k++) {
          var v = row[k];
          if (typeof v === 'number' && isFinite(v)) return v;
        }
      }
    }
  }
  return null;
}

/** Maps driving leg -> { miles, minutes } or null if no route. */
function drive_(origin, destination) {
  var directions = Maps.newDirectionFinder()
    .setOrigin(origin)
    .setDestination(destination)
    .setMode(Maps.DirectionFinder.Mode.DRIVING)
    .getDirections();

  if (!directions || !directions.routes || !directions.routes.length) return null;
  var leg = directions.routes[0].legs[0];
  return {
    miles: leg.distance.value / 1609.344, // meters -> miles
    minutes: leg.duration.value / 60       // seconds -> minutes
  };
}

function accountHasBase_(key) {
  for (var i = 0; i < BASE_FARE_ACCOUNTS.length; i++) {
    if (BASE_FARE_ACCOUNTS[i].toLowerCase() === key) return true;
  }
  return false;
}

function formatDuration_(totalMinutes) {
  var m = Math.max(0, Math.round(totalMinutes));
  var h = Math.floor(m / 60);
  var rem = m % 60;
  if (h > 0) return h + ' hr ' + rem + ' min';
  return rem + ' min';
}

function json_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function trimOrNull_(v) {
  if (v == null) return null;
  var s = String(v).trim();
  return s.length ? s : null;
}

function toNumber_(v, dflt) {
  if (v == null || String(v).trim() === '') return dflt;
  var n = Number(v);
  return isFinite(n) ? n : dflt;
}

function toBool_(v) {
  if (v == null) return false;
  var s = String(v).trim().toLowerCase();
  return s === 'true' || s === '1' || s === 'yes';
}

function round1_(n) { return Math.round(n * 10) / 10; }
function round2_(n) { return Math.round(n * 100) / 100; }
