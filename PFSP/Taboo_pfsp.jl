using Pkg
using XLSX
import Random
using DataFrames
using StatsBase



#EXCEL_F_NAME_1 = "Przykład_PFSP_50_10.xlsx"     
EXCEL_F_NAME_2 = "Dane_PFSP_100_10.xlsx"   
EXCEL_F_NAME_3 = "Dane_PFSP_200_10.xlsx"   
EXCEL_F_NAME_4 = "Dane_PFSP_50_20.xlsx"    

FILES = [EXCEL_F_NAME_2,EXCEL_F_NAME_3,EXCEL_F_NAME_4]


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


function get_data_values(data)
    result = copy(data)
    for i in 1:length(data)
        m,n = length(result[i][:,1]),length(result[i][1,:])
        result[i] = result[i][2:m,2:n]
    end
    return result
end


function calculateTasks(data)

    n_machines = length(data[1,:])
    n_tasks = length(data[:,1])
    results = copy(data)
    for i in 1:n_tasks
        for j in 1:n_machines-1
            if i == 1
                if j == 1
                results[1,1] = data[1,1] 
                end
                results[1,j+1] = results[1,j] + data[1,j+1]
            else
                if j == 1      
                    results[i,1] = results[i-1,1] + data[i,1]
                end
                if results[i,j] < results[i-1,j+1]
                    results[i,j+1] = data[i,j+1] + results[i-1,j+1]
                else
                    results[i,j+1] = data[i,j+1] + results[i,j]
                end 
            end
        end
    end
    return results[n_tasks,n_machines]
end

#swap
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

#insert
function find_neighbours2(current_sol)
    n = length(current_sol)
    element1 = current_sol[1]
    neighbours = [[] for i in 1:n-1]
    number_of_swaps = n
    for i in 2:n
        tmp = copy(current_sol)
        insert!(tmp,i,element1)
        deleteat!(tmp,1)
        neighbours[i-1] = tmp
    end
    return neighbours,length(neighbours)
end

#for swap
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

#for insert
function get_move2(route_old,route_new)
    result = [route_old[1],0]
    tmp = 1
    for i in 1:length(route_old)
        if route_old[i+1] != route_new[i]
            result[2] = route_old[i]
            break
        end
    end
    return result
end


function find_neighbours3(current_sol)
    n = length(current_sol)
    results = [[] for i in 1:n*n]
    tmp = 1
    moves = [[] for i in 1:n*n]
    for i in 1:n
        for j in 1:n
            if !(i==j) && !([i,j] in moves) && !([j,i] in moves)
                to_rev = copy(current_sol)
                results[tmp] = reverse(to_rev,i,j)
                moves[tmp] = [i,j]
                tmp +=1
            end
        end
    end
    results = unique(results)
    moves = unique(moves)
    deleteat!(moves,length(moves))
    deleteat!(results,length(results))
    return results,moves
end

function get_move3(new,neighbours,moves)
     for i in 1:length(neighbours)
         if new == neighbours[i]
             return moves[i]
         end
     end
 end


#function get_move3(new,neighbours,moves)
#    move = [1,1]
#    for i in 1:length(neighbours)
#        if new == neighbours[i]
#            move = moves[i]
#            return move
#        end
#    end
#    return move
#end



#neighbours  = find_neighbours(current_solution)[1] # n is number of swaps aka number of neighbours

#Finds a candidate in neighbourhood with lower distance 
function get_best_canditate(neighbours,current_solution,distance_matrix)
    criterion = calculateTasks(distance_matrix[current_solution,:])
    best = [current_solution] # tu zmienione 
    for i in 1:length(neighbours)
        tmp = calculateTasks(distance_matrix[neighbours[i],:])
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


function get_acceptable_canditate(neighbours,distance_matrix)
    criterion = calculateTasks(distance_matrix[neighbours[1],:])
    best = [[0]]
    for i in 1:length(neighbours)
        tmp = calculateTasks(distance_matrix[neighbours[i],:])
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
        distances[i] = calculateTasks(distance_matrix[neighbours[i],:])
    end
    df = DataFrame(Route = neighbours,Len = distances)
    return sort(df,["Len"])
end

# For #1(swap) and #2(insert) neighbourhoods  
function Taboo_Search(distance_matrix,starting,iterations,taboo_length) # symmetric current_solution
    tabo_list = [[] for k in 1:taboo_length]
    current_solution = starting
    for _ in 1:iterations
        neighbours = find_neighbours(current_solution)[1]                              #change to find_neighbours2
        best_s = get_best_canditate(neighbours,current_solution,distance_matrix)[1]
        move = get_move(current_solution,best_s)                                       #change to getmove2
        if move in tabo_list
            best_s_list = get_best_canditates(neighbours,distance_matrix).Route
            t = 1
            move_temp = tabo_list[1]
            while (move_temp in tabo_list)
                t += 1
                move_temp = get_move(current_solution,best_s_list[t])                 #change to getmove2
            end 
            current_solution = copy(best_s_list[t])
            update_taboolist(tabo_list,move_temp)
        else
            current_solution = copy(best_s)
            update_taboolist(tabo_list, move)        
        end
    end

    return current_solution, calculateTasks(distance_matrix[current_solution,:])
end

########################## dla 3 sasiedztwa (invert)

function Taboo_Search3(distance_matrix,starting,iterations,taboo_length) # symmetric current_solution
    tabo_list = [[] for k in 1:taboo_length]
    current_solution = starting
    for _ in 1:iterations
        neighbours,moves = find_neighbours3(current_solution)                              #
        best_s = get_best_canditate(neighbours,current_solution,distance_matrix)[1]
        move = get_move3(best_s,neighbours,moves)                                      
        if move in tabo_list
            best_s_list = get_best_canditates(neighbours,distance_matrix).Route
            t = 1
            move_temp = tabo_list[1]
            while (move_temp in tabo_list)
                t += 1
                move_temp = get_move3(best_s_list[t],neighbours,moves)                 #
            end 
            current_solution = copy(best_s_list[t])
            update_taboolist(tabo_list,move_temp)
        else
            current_solution = copy(best_s)
            update_taboolist(tabo_list, move)        
        end
    end

    return current_solution, calculateTasks(distance_matrix[current_solution,:])
end





########### MAIN ###############
#
#EXCEL_F_NAME_1 = "Przykład_PFSP_50_10.xlsx"     
#EXCEL_F_NAME_2 = "Dane_PFSP_100_10.xlsx"   
#EXCEL_F_NAME_3 = "Dane_PFSP_200_10.xlsx"   
#EXCEL_F_NAME_4 = "Dane_PFSP_50_20.xlsx"    
#
#FILES = [EXCEL_F_NAME_1,EXCEL_F_NAME_2,EXCEL_F_NAME_3,EXCEL_F_NAME_4]
#
#
all = get_data(FILES)
datas = get_data_values(all)

starting = [i for i in 1:length(datas[2][:,1])] 

random = sample(starting,length(starting),replace=false)
starting = random

result = Taboo_Search(datas[2],starting,10 ,10) 
print("working\n")   

print(result[1],result[2]," ",length(unique(result[1])))