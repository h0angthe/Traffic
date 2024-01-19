/**-
* Name: City Evacuation
* Author: Mathieu Bourgais & Patrick Taillandier
* Description:  Example model concerning the  use of the simpleBDI plug-in  with emotions. 
* A technological accident is simulated in one of the buildings of the city center.

* Tags: simple_bdi, emotion, evacuation
*/
model Driving

global {
	bool display3D <- false;
	file shape_file_roads <- file("../includes/HNTraffic/HanoiRoads.shp");
	file shape_file_nodes <- file("../includes/HNTraffic/HanoiNodes.shp");
	geometry shape <- envelope(shape_file_roads) + 50.0;
	graph road_network;
	int num_car <- 100;
	float lane_width <- 2.0;
	float e <- 0.5;
	float learning_rate <- 0.1;
	float discount_factor <- 0.9;
	float vt_tb;
	map<int, map<int, int>> q;
	float seed <- 0.0;
	init {
	//create the intersection and check if there are traffic lights or not by looking the values inside the type column of the shapefile and linking
	// this column to the attribute is_traffic_signal. 
		create intersection from: shape_file_nodes with: [is_traffic_signal::(read("type") = "traffic_signals")];

		//create road agents using the shapefile and using the oneway column to check the orientation of the roads if there are directed
		create road from: shape_file_roads with: [lanes::int(read("lanes")), oneway::string(read("oneway"))] {
			geom_display <- shape + (2.5 * lanes);
			maxspeed <- (lanes = 1 ? 40.0 : (lanes = 2 ? 50.0 : 70.0)) °km / °h;
			switch oneway {
				match "no" {
					create road {
						lanes <- max([1, int(myself.lanes / 2.0)]);
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- myself.maxspeed;
						geom_display <- myself.geom_display;
						linked_road <- myself;
						myself.linked_road <- self;
					}

					lanes <- int(lanes / 2.0 + 0.5);
				}

				match "-1" {
					shape <- polyline(reverse(shape.points));
				}

			}

		}

		map general_speed_map <- road as_map (each::(each.shape.perimeter / each.maxspeed));

		//creation of the road network using the road and intersection agents
		road_network <- (as_driving_graph(road, intersection)) with_weights general_speed_map;

		//initialize the traffic light
		ask intersection {
			do initialize;
		}

//		list<intersection> start <- intersection where (each.name = "intersection15" or each.name = "intersection52" or each.name = "intersection89");
//		end <- intersection where (each.name = "intersection31" or each.name = "intersection43" or each.name = "intersection20" or each.name = "intersection19");
		create car number: num_car with: (target: one_of(intersection)) {
			vehicle_length <- 3.8 #m;
			//car occupies 2 lanes
			num_lanes_occupied <- 1;
			max_speed <- 150 #km / #h;
			max_acceleration <- 5 / 3.6;
			right_side_driving <- true;
			proba_lane_change_up <- 0.1 + (rnd(500) / 500);
			proba_lane_change_down <- 0.5 + (rnd(500) / 500);
			
			proba_respect_priorities <- 1.0 - rnd(200 / 1000);
			proba_respect_stops <- [1.0];
			
			security_distance_coeff <- 5 / 9 * 3.6 * (1.5 - rnd(1000) / 1000);
			speed_coeff <- 1.2 - (rnd(400) / 1000);
			lane_change_limit <- 2;
	
			start_car <- one_of(intersection);
			
		} 
		try {
            string text <- file("q_table.txt");
            q <- eval_gaml(text);
        }

        catch {
            q <- [];
            save q to: "learn.txt" format: "txt";
        }
		} 
		reflex down_e  when: cycle mod 60=0 and e>0 {
		e <- e - 0.01;
	} 
		}

species intersection skills: [intersection_skill] {
	bool is_traffic_signal;
	list<list> stop;
	int time_to_change <- 100;
	int counter <- rnd(time_to_change);
	list<road> ways1;
	list<road> ways2;
	bool is_green;
	rgb color_fire;

	action initialize {
		if (is_traffic_signal) {
			do compute_crossing;
			stop << [];
			if (flip(0.5)) {
				do to_green;
			} else {
				do to_red;
			}

		}

	}

	action compute_crossing {
		if (length(roads_in) >= 2) {
			road rd0 <- road(roads_in[0]);
			list<point> pts <- rd0.shape.points;
			float ref_angle <- float(last(pts) direction_to rd0.location);
			loop rd over: roads_in {
				list<point> pts2 <- road(rd).shape.points;
				float angle_dest <- float(last(pts2) direction_to rd.location);
				float ang <- abs(angle_dest - ref_angle);
				if (ang > 45 and ang < 135) or (ang > 225 and ang < 315) {
					ways2 << road(rd);
				}

			}

		}

		loop rd over: roads_in {
			if not (rd in ways2) {
				ways1 << road(rd);
			}

		}

	}

	action to_green {
		stop[0] <- ways2;
		color_fire <- #green;
		is_green <- true;
	}

	action to_red {
		stop[0] <- ways1;
		color_fire <- #red;
		is_green <- false;
	}

	reflex dynamic_node when: is_traffic_signal {
		counter <- counter + 1;
		if (counter >= time_to_change) {
			counter <- 0;
			if is_green {
				do to_red;
			} else {
				do to_green;
			}

		}

	}

	aspect default {
		if (display3D) {
			if (is_traffic_signal) {
				draw box(1, 1, 10) color: #black;
				draw sphere(3) at: {location.x, location.y, 10} color: color_fire;
			}

		} else {
			if (is_traffic_signal) {
				draw circle(5) color: color_fire;
			}

		}

	}

}

//species that will represent the roads, it can be directed or not and uses the skill skill_road
species road skills: [road_skill] {
	int lanes;
	string oneway;
	geometry geom_display;

	aspect default {
		if (display3D) {
			draw geom_display color: #lightgray;
		} else {
			draw shape color: #white end_arrow: 5;
		}

	}

}

//People species that will move on the graph of roads to a target and using the driving skill
species car skills: [driving] {
	rgb color <- rnd_color(255); //rnd_color(255);
	intersection start_car <- nil;
	intersection target;
	car car_fl;
	car current_car;
	car car_ahead;
	car car_behind;
	int numA <- 0;
	int s;
	float distanceAB;
	map<int,int> acts;
	
	
	reflex v_tb when: final_target !=nil{
		float vt_tong <- 0.0 ;
		loop i over: car{
			vt_tong <- vt_tong + i.real_speed;
		}
		vt_tb <- vt_tong/num_car;
	}

	reflex time_to_go when: final_target = nil {
		do compute_path graph: road_network target: target;
	}

	reflex move when: final_target != nil {
			if(self.follower != nil){
			list<car> car_f1 <- (car where (each.name =self.follower.name));
            car_behind <- car_f1[0] = nil ? nil : car_f1[0];
         	 car_behind.car_ahead <- self;
			}
			if(car_ahead != nil){
			distanceAB <- self distance_to car_ahead;
            s <- int(distanceAB * 42 * 42 + self.real_speed * 42 + car_ahead.real_speed);
//			write "disAB :" +distanceAB +" xeAB: " +self;
		}
			if(q[s] = nil){
				map<int,int> st0 <- [0::0,1::0,2::0];
				q[s] <- st0;
			}
			acts <- q[s];
			float e_r <- rnd(1.0);
			if (e_r > e) {
				int maxS <- max(acts.values);
				int maxA <- 0;
				loop i over: acts.keys{
					if(acts[i]=maxS){
						maxA <- i;
					}
				}
				numA <- maxA ;
			} else {
				numA <- one_of(acts.keys);
			}
			
			if(numA = 2 and self.real_speed < 41){self.real_speed <- self.real_speed + self.max_acceleration ;}
			else if(numA = 0 and self.real_speed > 5){self.real_speed <- self.real_speed - self.max_deceleration  ;}
		
			do drive ;
			
	}
	reflex updateQ when: self.leading_distance != distanceAB {
		float reward <- ln(abs(real_speed + 0.000000001)) ;
		int s1 <- 0;
		if(self.follower != nil ){
			list<car> car_f1 <- (car where (each.name =self.follower.name));
            car_behind <- car_f1[0] = nil ? nil : car_f1[0];
            car_behind.car_ahead <- self;
			}
		if(car_ahead != nil){
			float distance_Cahead <- self distance_to car_ahead;
            s1 <- int(distance_Cahead * 42 * 42 + self.real_speed * 42 + car_ahead.real_speed);
//			write "dis2 :" +distance_Cahead +" xe2: " +self;
		}
		if(q[s1] = nil){
			map<int,int> st1 <- [0::1,1::0,2::0];
			q[s1] <- st1;
		}
		int val <- q[s][numA];
		q[s][numA] <- val +learning_rate * (reward + discount_factor *max(q[s1].values) - val );
		s <- s1;
	}
	reflex relocate when: final_target = nil and distance_to_current_target = 0.0{
		do unregister;
			location <- one_of(start_car).location;
	}

	point compute_position {
		if (current_road != nil) {
			float dist <- (road(current_road).num_lanes - current_lane - mean(range(num_lanes_occupied - 1)) - 0.5) * lane_width;
			if violating_oneway {
				dist <- -dist;
			}

			point shift_pt <- {cos(heading + 90) * dist, sin(heading + 90) * dist};
			return location + shift_pt;
		} else {
			return {0, 0};
		}

	}

	aspect default {
		if (current_road != nil) {
			point pos <- compute_position();
			draw rectangle(vehicle_length, lane_width * num_lanes_occupied) at: pos color: color rotate: heading border: #black;
			draw triangle(lane_width * num_lanes_occupied) at: pos color: #white rotate: heading + 90;
		}

	}

}

experiment HanoiCity type: gui {
	reflex savefile{
		save q to: "q_table.txt" format: txt;
	}
	reflex kt when: every(100#cycle){
		write "cycle"+ cycle+" : "+ vt_tb;
	}
	
	output synchronized: true {
		display city type: 3d background: #gray {
			species road;
			species intersection;
			species car;
		}
//		 display chart_display refresh:every(100#cycles) {
//             chart "Speed car" type: series  {
//                 data "vt_tb" value: vt_tb style: line color: #green ;
//	     	}
//	     }

	}

}




