import Random

using DataFrames
using Random
using StatsBase
using Pkg
import XLSX
import Random
import Pkg

EXCEL_F_NAME_1 = "TSP_29.xlsx"          # 29 cities    
EXCEL_F_NAME_2 = "Dane_TSP_48.xlsx"     # 48 cities
EXCEL_F_NAME_3 = "Dane_TSP_76.xlsx"     # 76 cities
EXCEL_F_NAME_4 = "Dane_TSP_127.xlsx"    # 127 cities

FILES = [EXCEL_F_NAME_1,EXCEL_F_NAME_2,EXCEL_F_NAME_3,EXCEL_F_NAME_4]


function get_data(xlsx_file_list)
    Pkg.add("XLSX")
    n = length(xlsx_file_list)
    objects = Vector(undef,n)
    sheets = Vector(undef,n)
    datas = Vector(undef,n)
    for i in eachindex(xlsx_file_list)
        objects[i] = XLSX.readxlsx(xlsx_file_list[i])
        sheets[i] = objects[i][XLSX.sheetnames(objects[i])[1]]
        datas[i] = sheets[i][:]
    end
    return datas    
end


function diagonal_to_zero(data)
    for i in 1:length(data[:,1])
        data[i,i] = 0
    end
    return data
end


function find_neighbours(current_sol)
    n_cities = length(current_sol)
    number_of_swaps = sum(range(1,n_cities-1))
    matr = [ [] for i=1:number_of_swaps]
    counter = 1
    for i in 1:n_cities
        for j in i:n_cities
            if i!=j
                new = copy(current_sol)
                tmp = current_sol[i]
                new[i] = current_sol[j]
                new[j] = tmp
                matr[counter] = new
                counter +=1 
            end
        end
    end
    return matr,number_of_swaps
end


function get_distance(city1,city2,distance_matrix)
    return distance_matrix[city1,city2]
end

function get_route_distance(route,distance_matrix)
    distance = 0
    for city in 1:length(route)-1
        distance += get_distance(route[city],route[city+1],distance_matrix)
    end
    distance += get_distance(route[1],route[length(route)],distance_matrix) # last city to city of origin 
    return distance
end

#Gets cities that have been switched
function get_move(route_old,route_new)
    result = [0,0]
    tmp = 1
    for i in 1:length(route_old)
        if route_old[i] != route_new[i]
            result[tmp] = route_old[i]
            tmp += 1
        end
    end
    return result
end


#neighbours  = find_neighbours(current_solution)[1] # n is number of swaps aka number of neighbours

#Finds a candidate in neighbourhood with lower distance 
function get_best_canditate(neighbours,current_solution,distance_matrix)
    criterion = get_route_distance(current_solution,distance_matrix)
    best = [current_solution] # tu zmienione 
    for i in 1:length(neighbours)
        tmp = get_route_distance(neighbours[i],distance_matrix)
        if tmp < criterion 
            best[1] = neighbours[i]
            criterion = tmp 
        end
    end
    return best
end

function rotate!(v,n::Int)
    l = length(v)
    l>1 || return v
    n = n % l
    n = n < 0 ? n+l : n
    n==0 && return v
    for i=1:gcd(n,l)
      tmp = v[i]
      dst = i
      src = dst+n
      while src != i
        v[dst] = v[src]
        dst = src
        src += n
        if src > l
          src -= l
        end
      end
      v[dst] = tmp
    end
    return v
  end
  
  move!(A,rng,loc) = begin 
    rotate!(view(A,min(first(rng),loc):max(last(rng),length(rng)+loc-1)),first(rng)-loc)
    return A
  end
 
function update_taboolist(taboo_list,move)
    move!(taboo_list,1:length(taboo_list)-1,2)
    taboo_list[1] = move
    return taboo_list
end

#gotta get sorted list of all
function get_acceptable_canditate(neighbours,distance_matrix)
    criterion = get_route_distance(neighbours[1],distance_matrix)
    best = [[0]]
    for i in 1:length(neighbours)
        tmp = get_route_distance(neighbours[i],distance_matrix)
        if tmp < criterion 
            best[1] = copy(neighbours[i])
            criterion = tmp 
        end
    end
    return best
end

function get_best_canditates(neighbours,distance_matrix)
    distances = [0.0 for i in 1:length(neighbours)]
    for i in 1:length(neighbours)
        distances[i] = get_route_distance(neighbours[i],distance_matrix)
    end
    df = DataFrame(Route = neighbours,Len = distances)
    return sort(df,["Len"])
end


function Taboo_Search(distance_matrix,route,iterations,taboo_length) # symmetric current_solution
    tabo_list = [[] for k in 1:taboo_length]
    current_solution = route
    for _ in 1:iterations
        neighbours = find_neighbours(current_solution)[1]
        best_s = get_best_canditate(neighbours,current_solution,distance_matrix)[1]
        move = get_move(current_solution,best_s)
        if move in tabo_list
            best_s_list = get_best_canditates(neighbours,distance_matrix).Route
            t = 1
            move_temp = tabo_list[1]
            while (move_temp in tabo_list)
                t += 1
                move_temp = get_move(current_solution,best_s_list[t])
            end 
            current_solution = copy(best_s_list[t])
            update_taboolist(tabo_list,move_temp)
        else
            current_solution = copy(best_s)
            update_taboolist(tabo_list, move)        
        end
    end

    return current_solution, get_route_distance(current_solution,distance_matrix)
end






###### TESTING 
#println("Droga")
#for i in 1:length(all[1][:,1])
#    println(all[1][i,:])
#end
#neighbours,n  = find_neighbours(current_solution)
#println("pierwsze sasiedztwo")
#for i in 1:n
#    distances = 0
#    for city in 1:n_cities-1
#        distances += get_distance(neighbours[i][city],neighbours[i][city+1],symmetric)
#    end
#    distances += get_distance(neighbours[i][1],neighbours[i][n_cities],symmetric) # last city to city of origin 
#    println(neighbours[i],distances)
#end
#
#print("\n\ntaboo\n")
#

######################## MAIN ###################
Random.seed!(5)


#parameters
iterat = [500,1000,5000,10000]
taboo  = [3,4,5,6]
all = get_data(FILES)
fk = [1,2,4,3]
for k in fk
    n_cities = length(all[k][:,1])
    current_solution = copy(sample(1:n_cities, n_cities, replace = false))
    if k == 3
        all[k] = copy(diagonal_to_zero(all[k]))
    end
    for i in iterat
        for tablen in taboo
            print("\n")
            println("Plik", k,"Iteracja ",i, " Dl taboo: ",tablen)
            println("Startowa sciezka: ", current_solution,"   ",Taboo_Search(all[k],current_solution,i,tablen))
            print("\n\n")
        end
    end
end

