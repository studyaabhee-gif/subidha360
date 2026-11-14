// Package catalog is the list of services customers can browse and search.
//
// Guide prices are typical ranges to set expectations, not quotes: the real
// price always comes from a provider's bid. They are starting estimates and
// should be replaced with real market data as jobs accumulate.
package catalog

// Service is one bookable task. Symptoms let people search by their problem.
type Service struct {
	ID         string   `bson:"id" json:"id"`
	Name       string   `bson:"name" json:"name"`
	Summary    string   `bson:"summary" json:"summary"`
	Symptoms   []string `bson:"symptoms" json:"symptoms"`
	Includes   []string `bson:"includes" json:"includes"`
	GuideFrom  int64    `bson:"guide_from" json:"guide_from_paisa"`
	GuideTo    int64    `bson:"guide_to" json:"guide_to_paisa"`
	Popular    bool     `bson:"popular" json:"popular"`
	CategoryID int      `bson:"category_id" json:"category_id"`
	// NameNe and SummaryNe are Nepali text set by admins. Services built in
	// have their Nepali in the app instead.
	NameNe    string `bson:"name_ne,omitempty" json:"name_ne,omitempty"`
	SummaryNe string `bson:"summary_ne,omitempty" json:"summary_ne,omitempty"`
	// Hidden services are kept for old jobs but cannot be booked.
	Hidden bool `bson:"hidden,omitempty" json:"hidden,omitempty"`
}

// Category groups services. Categories are fixed in code because each has
// its own icon and photo in the app; their text can be edited.
type Category struct {
	ID        int       `bson:"id" json:"id"`
	Slug      string    `bson:"slug" json:"slug"`
	Name      string    `bson:"name" json:"name"`
	Tagline   string    `bson:"tagline" json:"tagline"`
	NameNe    string    `bson:"name_ne,omitempty" json:"name_ne,omitempty"`
	TaglineNe string    `bson:"tagline_ne,omitempty" json:"tagline_ne,omitempty"`
	Services  []Service `bson:"services" json:"services"`
}

func rs(rupees int64) int64 { return rupees * 100 }

// defaults is the starting catalogue, saved to the database on first run.
// After that, admins change the stored copy and this list is not used.
var defaults = []Category{
	{ID: 1, Slug: "plumbing", Name: "Plumbing", Tagline: "Leaks, taps, tanks and pumps", Services: []Service{
		{ID: "tap-leak", Name: "Leaking tap repair", Summary: "Stop a dripping or loose tap, mixer or shower head.", Symptoms: []string{"tap dripping", "leaking tap", "mixer loose", "water not stopping"}, Includes: []string{"Finding the cause", "Replacing washers and seals", "Testing for leaks"}, GuideFrom: rs(400), GuideTo: rs(1200), Popular: true},
		{ID: "blocked-drain", Name: "Blocked drain clearing", Summary: "Clear slow or blocked sinks, floor drains and toilets.", Symptoms: []string{"sink blocked", "drain smell", "toilet not flushing", "water backing up"}, Includes: []string{"Clearing the blockage", "Checking the line", "Tidy-up after work"}, GuideFrom: rs(600), GuideTo: rs(2500), Popular: true},
		{ID: "water-pump", Name: "Water pump repair", Summary: "Fix a pump that will not start, hums or runs dry.", Symptoms: []string{"motor not starting", "no water pressure", "pump humming", "tank not filling"}, Includes: []string{"Electrical and pressure checks", "Priming the pump", "Advice on parts needed"}, GuideFrom: rs(800), GuideTo: rs(3500)},
		{ID: "tank-clean", Name: "Water tank cleaning", Summary: "Drain, scrub and refill rooftop or underground tanks.", Symptoms: []string{"dirty water", "tank smell", "sediment in water"}, Includes: []string{"Draining the tank", "Scrubbing and rinsing", "Refilling"}, GuideFrom: rs(1500), GuideTo: rs(5000)},
	}},
	{ID: 2, Slug: "electrical", Name: "Electrical", Tagline: "Wiring, lights and power faults", Services: []Service{
		{ID: "power-trip", Name: "Power fault finding", Summary: "Trace why a breaker keeps tripping or sockets are dead.", Symptoms: []string{"power keeps tripping", "mcb tripping", "no power in room", "socket not working"}, Includes: []string{"Fault tracing", "Safety checks", "Repair or a clear quote"}, GuideFrom: rs(500), GuideTo: rs(2500), Popular: true},
		{ID: "fan-light", Name: "Fan and light fitting", Summary: "Install or replace ceiling fans, lights and switches.", Symptoms: []string{"fan not working", "light flickering", "new light", "switch broken"}, Includes: []string{"Fitting and wiring", "Testing", "Removing the old unit"}, GuideFrom: rs(300), GuideTo: rs(1500), Popular: true},
		{ID: "inverter", Name: "Inverter and battery setup", Summary: "Install or service home inverters and backup batteries.", Symptoms: []string{"inverter not charging", "battery backup low", "backup power"}, Includes: []string{"Load check", "Installation or servicing", "Changeover test"}, GuideFrom: rs(1000), GuideTo: rs(4000)},
		{ID: "house-wiring", Name: "House wiring", Summary: "New wiring or rewiring for rooms and small buildings.", Symptoms: []string{"old wiring", "new room wiring", "burning smell from socket"}, Includes: []string{"Site visit", "Written scope", "Wiring and testing"}, GuideFrom: rs(3000), GuideTo: rs(25000)},
	}},
	{ID: 3, Slug: "cleaning", Name: "Cleaning", Tagline: "Homes, offices and move-ins", Services: []Service{
		{ID: "deep-clean", Name: "Full home deep clean", Summary: "A top-to-bottom clean for rooms, kitchen and bathrooms.", Symptoms: []string{"deep clean", "moving in", "before festival cleaning"}, Includes: []string{"Rooms and floors", "Kitchen surfaces", "Bathrooms"}, GuideFrom: rs(2500), GuideTo: rs(9000), Popular: true},
		{ID: "bathroom-clean", Name: "Bathroom cleaning", Summary: "Remove stains, scale and mould from bathrooms.", Symptoms: []string{"stained tiles", "bathroom smell", "hard water marks"}, Includes: []string{"Tiles and fittings", "Toilet and basin", "Scale removal"}, GuideFrom: rs(600), GuideTo: rs(1800)},
		{ID: "sofa-carpet", Name: "Sofa and carpet cleaning", Summary: "Shampoo and refresh sofas, carpets and mattresses.", Symptoms: []string{"dirty sofa", "carpet stain", "mattress cleaning"}, Includes: []string{"Vacuuming", "Shampoo clean", "Stain treatment"}, GuideFrom: rs(800), GuideTo: rs(3500)},
	}},
	{ID: 4, Slug: "carpentry", Name: "Carpentry", Tagline: "Doors, furniture and fittings", Services: []Service{
		{ID: "door-lock", Name: "Door and lock repair", Summary: "Fix doors that stick, drop or will not lock.", Symptoms: []string{"door not closing", "lock broken", "door hinge loose"}, Includes: []string{"Adjusting hinges", "Lock repair or fitting", "Planing if needed"}, GuideFrom: rs(400), GuideTo: rs(1800), Popular: true},
		{ID: "furniture-fix", Name: "Furniture repair", Summary: "Repair loose wardrobes, beds, chairs and drawers.", Symptoms: []string{"wardrobe door loose", "drawer stuck", "bed creaking"}, Includes: []string{"Tightening and gluing", "Replacing hardware", "Alignment"}, GuideFrom: rs(500), GuideTo: rs(2500)},
		{ID: "furniture-assembly", Name: "Furniture assembly", Summary: "Assemble and fix flat-pack or new furniture.", Symptoms: []string{"assemble bed", "new wardrobe", "tv wall mount"}, Includes: []string{"Assembly", "Wall fixing", "Packaging removal"}, GuideFrom: rs(500), GuideTo: rs(2000)},
	}},
	{ID: 5, Slug: "painting", Name: "Painting", Tagline: "Rooms, walls and damp repair", Services: []Service{
		{ID: "room-paint", Name: "Room painting", Summary: "Repaint one or more rooms, with prep and clean-up.", Symptoms: []string{"repaint room", "walls faded", "new colour"}, Includes: []string{"Covering furniture", "Wall preparation", "Two coats"}, GuideFrom: rs(4000), GuideTo: rs(15000), Popular: true},
		{ID: "damp-repair", Name: "Damp and seepage repair", Summary: "Treat damp patches, peeling paint and wall seepage.", Symptoms: []string{"damp wall", "paint peeling", "ceiling leak marks"}, Includes: []string{"Finding the source", "Waterproof treatment", "Repainting the patch"}, GuideFrom: rs(2500), GuideTo: rs(12000)},
	}},
	{ID: 6, Slug: "appliances", Name: "Appliances", Tagline: "Washers, fridges and geysers", Services: []Service{
		{ID: "washing-machine", Name: "Washing machine repair", Summary: "Fix machines that leak, shake or will not spin.", Symptoms: []string{"washing machine not spinning", "machine leaking", "drum noise"}, Includes: []string{"Diagnosis", "Repair", "Trial wash"}, GuideFrom: rs(700), GuideTo: rs(3500), Popular: true},
		{ID: "fridge", Name: "Fridge repair", Summary: "Fix fridges that are not cooling or are noisy.", Symptoms: []string{"fridge not cooling", "fridge noise", "freezer ice"}, Includes: []string{"Diagnosis", "Gas and thermostat checks", "Repair"}, GuideFrom: rs(800), GuideTo: rs(4500)},
		{ID: "geyser", Name: "Geyser repair and fitting", Summary: "Repair or install electric water heaters.", Symptoms: []string{"no hot water", "geyser leaking", "new geyser"}, Includes: []string{"Element and thermostat checks", "Installation", "Leak test"}, GuideFrom: rs(600), GuideTo: rs(2500)},
		{ID: "ac-service", Name: "AC servicing", Summary: "Clean, service or repair air conditioners.", Symptoms: []string{"ac not cooling", "ac water leak", "ac smell"}, Includes: []string{"Filter and coil cleaning", "Gas pressure check", "Performance test"}, GuideFrom: rs(1000), GuideTo: rs(3500)},
	}},
	{ID: 7, Slug: "computer", Name: "Computer & Wi-Fi", Tagline: "Laptops, printers and networks", Services: []Service{
		{ID: "laptop", Name: "Laptop and PC repair", Summary: "Speed up, clean or repair laptops and desktops.", Symptoms: []string{"slow laptop", "laptop not starting", "virus", "overheating"}, Includes: []string{"Diagnosis", "Clean-up and updates", "Repair advice"}, GuideFrom: rs(500), GuideTo: rs(3000), Popular: true},
		{ID: "wifi", Name: "Wi-Fi and network setup", Summary: "Fix weak Wi-Fi and set up routers and cabling.", Symptoms: []string{"wifi slow", "no internet in room", "router setup"}, Includes: []string{"Coverage check", "Router setup", "Testing"}, GuideFrom: rs(500), GuideTo: rs(2500)},
		{ID: "printer", Name: "Printer repair", Summary: "Fix paper jams, poor prints and connection problems.", Symptoms: []string{"printer not printing", "paper jam", "printer offline"}, Includes: []string{"Diagnosis", "Cleaning", "Driver setup"}, GuideFrom: rs(500), GuideTo: rs(2000)},
	}},
	{ID: 8, Slug: "pest-control", Name: "Pest Control", Tagline: "Cockroaches, ants and termites", Services: []Service{
		{ID: "general-pest", Name: "General pest treatment", Summary: "Treat cockroaches, ants and other household pests.", Symptoms: []string{"cockroaches", "ants", "bed bugs"}, Includes: []string{"Inspection", "Treatment", "Prevention advice"}, GuideFrom: rs(1500), GuideTo: rs(6000)},
		{ID: "termite", Name: "Termite treatment", Summary: "Find and treat termites in wood and walls.", Symptoms: []string{"termites", "wood damage", "white ants"}, Includes: []string{"Inspection", "Targeted treatment", "Follow-up advice"}, GuideFrom: rs(3000), GuideTo: rs(15000)},
	}},
}
